using System;
using SweetEditor;

namespace SweetEditor.Avalonia.Demo;

internal sealed class DemoSelectionMenuListener : ISelectionMenuListener
{
    private readonly Action<string> onSelected;

    public DemoSelectionMenuListener(Action<string> onSelected)
    {
        this.onSelected = onSelected;
    }

    public void OnSelectionMenuItemSelected(string itemId)
    {
        onSelected(itemId);
    }
}
