import pandas as pd

df = pd.read_csv('storageaccounts_nonprod.csv')

print("Division unique values:")
print(', '.join(df['Division'].unique().tolist()))

print("\nDepartment unique values:")
print(', '.join(df['Department'].dropna().unique().tolist()))

print("\nService Name unique values:")
print(', '.join(df['ServiceName'].dropna().unique().tolist()))

print("\nEnvironment unique values:")
print(', '.join(df['Environment'].dropna().unique().tolist()))

print("\nLocation unique values:")
print(', '.join(df['location'].dropna().unique().tolist()))