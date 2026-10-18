using System.Text.Json;
using VoiceNotes.Core.Models;

namespace VoiceNotes.Core.Tests.Models;

public sealed class HotKeyTests
{
    [Fact]
    public void DefaultDictationIsControlAltSpace()
    {
        Assert.Equal("Ctrl+Alt+Space", HotKey.DefaultDictation.DisplayString);
        Assert.Equal(0x20, HotKey.DefaultDictation.VirtualKey);
    }

    [Fact]
    public void DisplayOrdersModifiersLikeWindowsMenus()
    {
        var hotKey = new HotKey(HotKeyModifiers.Windows | HotKeyModifiers.Shift | HotKeyModifiers.Control, 0x44, "D");
        Assert.Equal("Ctrl+Shift+Win+D", hotKey.DisplayString);
    }

    [Fact]
    public void DisplaysSingleKeyWithoutModifiers()
    {
        Assert.Equal("F5", new HotKey(HotKeyModifiers.None, 0x74, "F5").DisplayString);
    }

    [Fact]
    public void RoundTripsThroughJson()
    {
        var json = JsonSerializer.Serialize(HotKey.DefaultDictation);
        Assert.Equal(HotKey.DefaultDictation, JsonSerializer.Deserialize<HotKey>(json));
    }
}
