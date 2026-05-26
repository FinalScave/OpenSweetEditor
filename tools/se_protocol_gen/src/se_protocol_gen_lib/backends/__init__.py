from .cpp import generate_cpp
from .ets import generate_ets
from .java import generate_java
from .swift import generate_swift

BACKENDS = {
    "cpp": generate_cpp,
    "ets": generate_ets,
    "java": generate_java,
    "swift": generate_swift,
}
