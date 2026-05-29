#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public sealed partial class LinkedEditingModel {
        public List<TabStopGroup> Groups { get; set; } = new();
    }

    public sealed partial class TabStopGroup {
        public int Index { get; set; } = 0;
        public List<TextRange> Ranges { get; set; } = new();
        public string DefaultText { get; set; } = string.Empty;
    }
}
