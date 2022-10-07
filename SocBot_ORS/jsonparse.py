import json
import pandas as pd
import matplotlib.pyplot as plt

with open('response.geojson', 'r') as f:
    data = json.loads(f.read())

df = pd.DataFrame(data['features'][0]['geometry']['coordinates'])
df.columns=['lat', 'lng', 'ele']
print(df)
# df['ele'].plot()
# plt.show()

df2 = pd.DataFrame(data['features'][0]['properties']['segments'][0]['steps'])
df2['distance_per_waypoint'] = df2.apply(lambda row: row['distance']/(row['way_points'][1] - row['way_points'][0] + 1), axis=1)
print(df2)