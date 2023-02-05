class Primes:
    def __init__(self, max):
        self.internal = range(2,max+1)
    
    def __next__(self):
        i = self.internal.__iter__().__next__()
        self.internal = filter(lambda n : n % i != 0, self.internal)
        return i

    def __iter__(self): return self

for i in Primes(100):
    print(i)