import json
import os
import boto3


from slack_bolt import App, Say, SetStatus
from slack_bolt.adapter.aws_lambda import SlackRequestHandler

# Initialize AWS clients for Bedrock and Secrets Manager
bedrock_runtime_client = boto3.client("bedrock-runtime")
secretsmanager_client = boto3.client("secretsmanager")

slack_token = json.loads(
    secretsmanager_client.get_secret_value(SecretId=os.environ.get("token"))[
        "SecretString"
    ]
)["token"]
slack_signing_secret = json.loads(
    secretsmanager_client.get_secret_value(SecretId=os.environ.get("secret"))[
        "SecretString"
    ]
)["secret"]

# Configuration from template variables
BEDROCK_MODEL_ID = "${bedrock_model_id}"

# process_before_response must be True when running on FaaS
# see also https://tools.slack.dev/bolt-python/concepts/lazy-listeners/ for an explainer on how to handle long running processes
app = App(
    process_before_response=True, signing_secret=slack_signing_secret, token=slack_token
)


def respond_to_slack_within_3_seconds(body, ack):
    text = body.get("text")
    if text is None or len(text) == 0:
        ack(":x: Usage: /start-process (description here)")
    else:
        ack(f"Accepted! (task: {body['text']})")


def call_bedrock(question):
    body = json.dumps(
        {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 3000,
            "system": "You are a helpful Slack bot assistant. Respond in a friendly and concise manner.",
            "messages": [{"role": "user", "content": question}],
            "temperature": 0.5,
        }
    )

    model_id = BEDROCK_MODEL_ID
    accept = "application/json"
    content_type = "application/json"

    # Call the Bedrock AI model
    response = bedrock_runtime_client.invoke_model(
        body=body, modelId=model_id, accept=accept, contentType=content_type
    )

    # Process the response from the Bedrock AI model
    response_content = response["body"].read().decode("utf-8")
    response_body = json.loads(response_content)

    return response_body.get("content")[0].get("text")


import time


def run_long_process(respond, body):
    time.sleep(5)  # longer than 3 seconds
    respond(f"Completed! (task: {body['text']})")


app.command("/start-process")(
    ack=respond_to_slack_within_3_seconds,  # responsible for calling `ack()`
    lazy=[run_long_process],  # unable to call `ack()` / can have multiple functions
)


def acknowledge_message(body, logger, set_status: SetStatus):
    """Acknowledge the message event and set typing indicator."""
    event = body.get("event", {})
    if "bot_id" in event and event["bot_id"] is not None:
        return
    try:
        set_status("is typing...")
    except Exception as e:
        logger.error(f"Error setting status: {e}")


def process_message_lazily(body, logger, say: Say):
    """Process the message, call Bedrock, and send a reply."""
    event = body.get("event", {})
    text = event.get("text")

    if "bot_id" in event and event["bot_id"] is not None:
        return

    if not text:
        logger.info("No text in message, skipping Bedrock call.")
        return

    try:
        print(event)
        generated_text = call_bedrock(text)
        logger.info(f"Bedrock response: {generated_text}")
        say(generated_text)
    except Exception as e:
        logger.error(f"Error processing event: {e}")
        say(
            "Sorry, there was an error communicating with AWS Bedrock. The good news is that your Slack App works! If you want to get Bedrock working, check that you've "
            "<https://docs.aws.amazon.com/bedrock/latest/userguide/model-access-modify.html|enabled model access> "
            "and are using the correct <https://docs.aws.amazon.com/bedrock/latest/userguide/cross-region-inference.html#cross-region-inference-use|inference profile>. "
            "If both of these are true, there is some other error. Check your lambda logs for more info."
        )


app.event("message")(ack=acknowledge_message, lazy=[process_message_lazily])


def handle_challenge(event):
    body = json.loads(event["body"])

    return {
        "statusCode": 200,
        "headers": {"x-slack-no-retry": "1"},
        "body": body["challenge"],
    }


def handler(event, context):
    event_body = json.loads(event.get("body"))
    response = None
    if event_body.get("type") == "url_verification":
        response = handle_challenge(event)
        return response
    else:
        slack_handler = SlackRequestHandler(app=app)
        return slack_handler.handle(event, context)
