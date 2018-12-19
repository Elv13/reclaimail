# Get your emails, they're yours

Fetch GMail content using OAUTH2 instead of hardcoded passwords
in plain text

See the sample offlineimap file for how to get the tokens

    # Never trust someone else image with this info, always build it
    sudo docker build . -t my/offlineimap
    
    # Run the fetch
    sudo docker run -it -eSECRET='your refresh token' \
        -eACCESS_TOKEN='your access token' \
        -eCLIENT_ID='something ending with apps.googleusercontent.com' \
        -eEMAIL='your email address' \
        -v /path/to/maildir:/home/offlineimap/GMail \
        --entrypoint=/bin/bash my/offlineimap
