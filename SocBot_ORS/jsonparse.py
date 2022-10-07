import json
import pandas as pd
import matplotlib.pyplot as plt

with open('response.geojson', 'r') as f:
    data = json.loads(f.read())

df = pd.DataFrame(data['features'][0]['geometry']['coordinates'])
df.columns=['lat', 'lng', 'ele']
df['ele'].plot()
plt.show()