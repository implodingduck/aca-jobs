import os
# calculate the fibonacci number of a given number

def fibonacci(n: int) -> int:
    if n <= 0:
        return 0
    elif n == 1:
        return 1
    else:
        a, b = 0, 1
        for _ in range(2, n + 1):
            a, b = b, a + b
        return b

if __name__ == "__main__":
    n = int(os.getenv("FIBONACCI_NUMBER", 10))
    result = fibonacci(n)
    print(f"The {n} Fibonacci number is: {result}")
    