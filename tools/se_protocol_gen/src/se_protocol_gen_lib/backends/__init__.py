from .cpp import generate_cpp
from .csharp import generate_csharp
from .dart import generate_dart
from .ets import generate_ets
from .java import generate_java
from .swift import generate_swift

BACKENDS = {
    "cpp": generate_cpp,
    "csharp": generate_csharp,
    "dart": generate_dart,
    "ets": generate_ets,
    "java": generate_java,
    "swift": generate_swift,
}
