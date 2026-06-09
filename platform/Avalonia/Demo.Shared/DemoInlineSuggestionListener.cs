using System;
using SweetEditor;

namespace SweetEditor.Avalonia.Demo;

internal sealed class DemoInlineSuggestionListener : IInlineSuggestionListener
{
    private readonly Action<string> updateStatus;

    public DemoInlineSuggestionListener(Action<string> updateStatus)
    {
        this.updateStatus = updateStatus;
    }

    public void OnSuggestionAccepted(InlineSuggestion suggestion)
        => updateStatus($"Accepted inline suggestion at {suggestion.Line}:{suggestion.Column}");

    public void OnSuggestionDismissed(InlineSuggestion suggestion)
        => updateStatus($"Dismissed inline suggestion at {suggestion.Line}:{suggestion.Column}");
}
