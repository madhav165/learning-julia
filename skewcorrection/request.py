import requests
import time
import os
url = 'http://127.0.0.1:5000'

# resp = requests.get(url)
# print(resp.status_code)
# print(resp.content)
start = time.time()
input_file = "./skewcorrection/original.png"
for i in range(100):
    with open(input_file, 'rb') as f:
        files={'original_serve_py.png': f}
        resp = requests.post(url, files=files)
        with open('./skewcorrection/skew_corrected_py_client.png', 'wb') as f2:
            f2.write(resp.content)
end = time.time()
print('Time taken = {0:0.2f} sec'.format(end-start))
