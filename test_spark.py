from pyspark.sql import SparkSession
from pyspark.sql.functions import col, expr

def main():
    spark = SparkSession.builder \
        .appName("PySpark Test") \
        .getOrCreate()

    data = [("Alice", 25), ("Bob", 30), ("Charlie", 35), ("David", 40)]
    df = spark.createDataFrame(data, ["name", "age"])

    print("Original DataFrame:")
    df.show()

    result = df.select("name", "age") \
        .filter(col("age") > 30) \
        .withColumn("age_group", expr("CASE WHEN age < 35 THEN 'Young' ELSE 'Senior' END"))

    print("Transformed DataFrame:")
    result.show()

    avg_age = df.agg({"age": "avg"}).collect()[0][0]
    print(f"Average age: {avg_age:.2f}")

    result.write.csv("/opt/spark/work-dir/output", header=True, mode="overwrite")
    print("Results written to /opt/spark/work-dir/output")

    spark.stop()

if __name__ == "__main__":
    main()