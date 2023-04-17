

# Clone and Run locally

##  Create Virtual env

 > !NOTE
 > Needs to be named **`antenv`** for app service to locate it!

```
$ python3 -m venv antenv
$ source antenv/bin/activate
```

 > !NOTE To deactivate 
 > `$ deactivate`


$ python -m pip install --upgrade pip

## Install some test packages in the virtual env

```
$ python3 -m pip install -r requirements.txt
```

##  Create a demo app.py

```
echo "import openai;
from flask import Flask

app = Flask(__name__)


@app.route('/')
def hello():
    return 'Hello, World, openai api_base=%s' % openai.api_base
" > app.py
```


## Run locally

```
flask run
```

#  Deploy to Azure

## Create Infra
az group create --name my-python-demo
az deployment group create -g my-python-demo --template-file ./infra/main.bicep --parameters name=mypyapp01

# Add app.py and the virtual environment to the zip file
zip -r ./release.zip app.py  antenv/

# Release to App Service
az webapp deploy -g rg -n appname --src-path ./release.zip

# Look for the Log stream of app service 