from pyspark.sql import SparkSession
from pyspark.sql.functions import col, expr

def main():
    # Create a SparkSession
    spark = SparkSession.builder \
        .appName("PySpark Test") \
        .getOrCreate()

    # Create a sample DataFrame
    data = [("Alice", 25), ("Bob", 30), ("Charlie", 35), ("David", 40)]
    df = spark.createDataFrame(data, ["name", "age"])

    # Show the DataFrame
    print("Original DataFrame:")
    df.show()

    # Perform some transformations
    result = df.select("name", "age") \
        .filter(col("age") > 30) \
        .withColumn("age_group", expr("CASE WHEN age < 35 THEN 'Young' ELSE 'Senior' END"))

    # Show the result
    print("Transformed DataFrame:")
    result.show()

    # Perform aggregation
    avg_age = df.agg({"age": "avg"}).collect()[0][0]
    print(f"Average age: {avg_age:.2f}")

    # Write the result to a CSV file in the mounted directory
    result.write.csv("/opt/spark/work-dir/output", header=True, mode="overwrite")
    print("Results written to /opt/spark/work-dir/output")

    # Stop the SparkSession
    spark.stop()

if __name__ == "__main__":
    main()