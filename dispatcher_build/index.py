import json
import boto3
import os

def handler(event, context):
    """
    Dispatcher Lambda that immediately returns 200 OK and invokes main Lambda async
    """
    
    # Get the main Lambda function name from environment
    main_function_name = os.environ['MAIN_LAMBDA_FUNCTION']
    
    # Create Lambda client
    lambda_client = boto3.client('lambda')
    
    try:
        # Invoke the main Lambda function asynchronously
        lambda_client.invoke(
            FunctionName=main_function_name,
            InvocationType='Event',  # Asynchronous invocation
            Payload=json.dumps(event)
        )
        
        # Return immediate 200 OK response for Slack
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'message': 'Request received and processing'
            })
        }
        
    except Exception as e:
        print(f"Error invoking main Lambda: {str(e)}")
        # Still return 200 to Slack to avoid retries
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'message': 'Request received'
            })
        }
