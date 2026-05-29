from .csharp import augment_csharp
from .dart import augment_dart
from .java import augment_java


AUGMENTERS = {
    "csharp": augment_csharp,
    "dart": augment_dart,
    "java": augment_java,
}
