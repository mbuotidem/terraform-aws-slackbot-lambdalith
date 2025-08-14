import json
import os
import boto3


from slack_bolt import App, Say
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


import time


def run_long_process(respond, body):
    time.sleep(5)  # longer than 3 seconds
    respond(f"Completed! (task: {body['text']})")


app.command("/start-process")(
    ack=respond_to_slack_within_3_seconds,  # responsible for calling `ack()`
    lazy=[run_long_process],  # unable to call `ack()` / can have multiple functions
)


@app.event("message")
def handle_message_events(body, logger, say: Say):
    logger.info(body)
    print(body["event"]["channel"])
    say("Allo", channel=body["event"]["channel"])


def handler(event, context):
    slack_handler = SlackRequestHandler(app=app)
    return slack_handler.handle(event, context)
