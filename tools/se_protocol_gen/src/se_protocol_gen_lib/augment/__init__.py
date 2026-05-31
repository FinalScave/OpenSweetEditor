from .csharp import augment_csharp
from .dart import augment_dart
from .ets import augment_ets
from .java import augment_java


AUGMENTERS = {
    "csharp": augment_csharp,
    "dart": augment_dart,
    "ets": augment_ets,
    "java": augment_java,
}
