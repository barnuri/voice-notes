namespace VoiceNotes.Core.Models;

public sealed record HotKey(HotKeyModifiers Modifiers, int VirtualKey, string KeyLabel)
{
    private const int SpaceVirtualKey = 0x20;
    private const string Separator = "+";

    private static readonly (HotKeyModifiers Modifier, string Label)[] ModifierLabels =
    [
        (HotKeyModifiers.Control, "Ctrl"),
        (HotKeyModifiers.Alt, "Alt"),
        (HotKeyModifiers.Shift, "Shift"),
        (HotKeyModifiers.Windows, "Win"),
    ];

    public static HotKey DefaultDictation { get; } =
        new(HotKeyModifiers.Control | HotKeyModifiers.Alt, SpaceVirtualKey, "Space");

    public string DisplayString =>
        string.Join(Separator, ModifierLabels
            .Where(entry => Modifiers.HasFlag(entry.Modifier))
            .Select(entry => entry.Label)
            .Append(KeyLabel));

    public override string ToString() => DisplayString;
}
