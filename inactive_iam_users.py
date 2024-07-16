import boto3
from datetime import datetime, timedelta, timezone

def send_email(inactive_users):
    # Set your SES region, sender and receiver email addresses
    region = 'us-east-1'
    sender_email = 'patu147@gmail.com'
    recipient_email = 'shoaibmm7@gmail.com'


    # Initialize Boto3 SES client
    ses = boto3.client('ses', region_name=region)

    # Create the email subject and body
    if inactive_users:
        subject = "AWS IAM Users Inactive for More Than 90 Days"
    else:
        subject = "No Inactive AWS IAM Users Found"
    body_html = create_email_body_html(inactive_users)

    # Send the email
    response = ses.send_email(
        Source=sender_email,
        Destination={'ToAddresses': [recipient_email]},
        Message={
            'Subject': {'Data': subject},
            'Body': {'Html': {'Data': body_html}}
        }
    )

    print("Email sent. Message ID:", response['MessageId'])

def create_email_body_html(inactive_users):
    if inactive_users:
        # Create an HTML table
        table_html = "<table border='1' cellspacing='0' cellpadding='5' style='text-align: center;'><tr><th>Username</th><th>Inactive Days</th></tr>"

        # Add rows to the table
        for user in inactive_users:
            table_html += f"<tr><td>{user['UserName']}</td><td>{user['DaysInactive']}</td></tr>"

        table_html += "</table>"
        body_html = (
            "You are receiving this email because there are IAM users in your AWS account who have been inactive for more than 90 days. "
            "Please find below the list of inactive users along with the number of days they have been inactive:<br><br>"
            f"{table_html}<br><br>"
        )
    else:
        body_html = (
            "You are receiving this email because there are no inactive IAM users in your AWS account who have been inactive for more than 90 days. "
            "No further action is required at this time.<br><br>"
        )

    return body_html

def lambda_handler(event, context):
    # Initialize Boto3 IAM client
    iam = boto3.client('iam')

    # Get the current date in UTC
    current_date = datetime.utcnow().replace(tzinfo=timezone.utc)

    # Calculate the date threshold for inactivity (90 days ago) in UTC
    threshold_date = current_date - timedelta(days=1)

    # List all IAM users
    response = iam.list_users()

    # Check each user's last password usage date and if the password is enabled
    inactive_users = []
    for user in response['Users']:
        user_name = user['UserName']
        try:
            # Get user details to access PasswordLastUsed information
            user_details = iam.get_user(UserName=user_name)
            password_last_used = user_details['User'].get('PasswordLastUsed')

            # Check if the user has a password enabled
            if password_last_used is not None and password_last_used <= threshold_date:
                days_inactive = (current_date - password_last_used).days
                inactive_users.append({
                    'UserName': user_name,
                    'DaysInactive': days_inactive
                })
        except iam.exceptions.NoSuchEntityException:
            # Handle the case where user details are not accessible (e.g., due to insufficient permissions)
            print(f"Could not retrieve details for IAM User {user_name}")

    # Send an email with the inactive user list
    send_email(inactive_users)

    return {
        'statusCode': 200,
        'body': {
            'InactiveUsers': inactive_users
        }
    }

