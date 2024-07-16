import pandas as pd
import logging

csv_file = 'snapshots.csv'
df = pd.read_csv(csv_file)

for index, row in df.iterrows():
    print(row['Subscription Name'], row['Resource Group Name'], row['Snapshot Name'])


