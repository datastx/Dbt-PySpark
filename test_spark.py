from pyspark.sql import SparkSession
from pyspark.sql.functions import col, expr, window, sum as spark_sum, to_timestamp
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, TimestampType

def main():
    spark = SparkSession.builder \
        .appName("PySpark Advanced Test") \
        .getOrCreate()

    # Create a more complex dataset
    schema = StructType([
        StructField("name", StringType(), True),
        StructField("age", IntegerType(), True),
        StructField("department", StringType(), True),
        StructField("salary", IntegerType(), True),
        StructField("timestamp", StringType(), True)  # Changed to StringType
    ])

    data = [
        ("Alice", 25, "Engineering", 80000, "2023-01-01 12:00:00"),
        ("Bob", 30, "Sales", 65000, "2023-01-01 12:30:00"),
        ("Charlie", 35, "Engineering", 95000, "2023-01-01 13:00:00"),
        ("David", 40, "Marketing", 70000, "2023-01-01 13:30:00"),
        ("Eve", 28, "Engineering", 85000, "2023-01-01 14:00:00")
    ]

    df = spark.createDataFrame(data, schema)

    # Convert the timestamp string to actual timestamp
    df = df.withColumn("timestamp", to_timestamp("timestamp"))

    print("Original DataFrame:")
    df.show(truncate=False)
    df.printSchema()

    # Perform some transformations
    result = df.select("name", "age", "department", "salary") \
        .filter(col("age") > 30) \
        .withColumn("salary_category", expr("CASE WHEN salary < 80000 THEN 'Low' WHEN salary < 90000 THEN 'Medium' ELSE 'High' END"))

    print("Transformed DataFrame:")
    result.show()

    # Perform aggregations
    dept_stats = df.groupBy("department") \
        .agg(spark_sum("salary").alias("total_salary"),
             expr("avg(salary)").alias("avg_salary"),
             expr("max(age)").alias("max_age"))

    print("Department Statistics:")
    dept_stats.show()

    # Perform a window operation
    from pyspark.sql.window import Window
    window_spec = Window.partitionBy("department").orderBy("salary")
    df_with_rank = df.withColumn("salary_rank", expr("rank()").over(window_spec))

    print("DataFrame with Salary Rank:")
    df_with_rank.show()

    # Perform a time-based window operation
    time_window = df.groupBy(window("timestamp", "1 hour")) \
        .agg(spark_sum("salary").alias("total_salary_per_hour"))

    print("Hourly Salary Totals:")
    time_window.show(truncate=False)

    spark.stop()

if __name__ == "__main__":
    main()