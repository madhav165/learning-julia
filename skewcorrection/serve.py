import os
from flask import Flask, request, send_file
from PIL import Image as im
from main import *
    
app = Flask(__name__)


@app.route('/', methods = ['GET', 'POST'])
def hello_world():
    if request.method == 'POST':
        file = request.files['original_serve_py.png']
        img = im.open(file)
        img.save(os.path.join('skewcorrection', 'original_serve_py.png'))
        remove_skew(img)
        return send_file('skew_corrected_py_serve.png', mimetype='image/png', download_name='skew_corrected_py_client.png')
    else:
        return 'Hello, World'

if __name__ == '__main__':
    app.run()
