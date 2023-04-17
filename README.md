


#  Create Virtual env - Needs to be named "antenv" for app service to locate it!

$ python3 -m venv antenv
$ source antenv/bin/activate
$ python -m pip install --upgrade pip

#  Install some test packages in the virtual env
$ pip install flask
$ pip install openai

# Create a demo app.py
echo "import openai;
from flask import Flask

app = Flask(__name__)


@app.route('/')
def hello():
    return 'Hello, World, openai api_base=%s' % openai.api_base
" > app.py

# Run locally
flask run

# Add app.py and the virtual environment to the zip file
zip -r ./release.zip app.py  antenv/

# Release to App Service
az webapp deploy -g rg -n appname --src-path ./release.zip

# Look for the Log stream of app service 