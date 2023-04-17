import openai;
from flask import Flask

app = Flask(__name__)


@app.route('/')
def hello():
    return 'Hello, World, openai api_base=%s' % openai.api_base

