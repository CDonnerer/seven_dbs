"""Loading data into mongodb with python client
"""
import csv

import pymongo


def main():
    client = pymongo.MongoClient("mongodb://mongo:mongo@localhost:27017/")

    db = client["7dbs"]
    collection = db["cities"]
    cities = []

    with open("data/cities1000.txt") as f:
        rows = csv.reader(f, delimiter="\t")
        print("Reading in records...")
        for row in rows:
            city = {
                "name": row[2],
                "county": row[8],
                "timezone": row[17],
                "population": int(row[14]),
                "location": {"longitude": float(row[5]), "latitude": float(row[4])},
            }
            cities.append(city)
        print("Inserting records...")
        collection.insert_many(cities)


if __name__ == "__main__":
    main()
