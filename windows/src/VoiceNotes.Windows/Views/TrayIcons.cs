using System.Drawing.Drawing2D;
using VoiceNotes.Core.Models;
using VoiceNotes.Windows.Native;

namespace VoiceNotes.Windows.Views;

internal sealed class TrayIcons : IDisposable
{
    private const int IconSize = 32;
    private readonly Icon idle = Draw(Palette.Idle);
    private readonly Icon listening = Draw(Palette.Recording);
    private readonly Icon paused = Draw(Palette.Paused);

    internal Icon For(DictationPhase phase) => phase switch
    {
        DictationPhase.Listening => listening,
        DictationPhase.Paused => paused,
        _ => idle,
    };

    public void Dispose()
    {
        idle.Dispose();
        listening.Dispose();
        paused.Dispose();
    }

    private static Icon Draw(Color background)
    {
        using var bitmap = new Bitmap(IconSize, IconSize);
        using (var graphics = Graphics.FromImage(bitmap))
        {
            graphics.SmoothingMode = SmoothingMode.AntiAlias;
            using var fill = new SolidBrush(background);
            graphics.FillEllipse(fill, 0, 0, IconSize - 1, IconSize - 1);
            using var white = new SolidBrush(Color.White);
            using var capsule = RoundedRectangles.Capsule(new RectangleF(12, 6, 8, 14));
            graphics.FillPath(white, capsule);
            using var stroke = new Pen(Color.White, 2.2f);
            graphics.DrawArc(stroke, 9, 11, 14, 12, 0, 180);
            graphics.DrawLine(stroke, 16, 23, 16, 27);
        }
        var handle = bitmap.GetHicon();
        try
        {
            using var borrowed = Icon.FromHandle(handle);
            return (Icon)borrowed.Clone();
        }
        finally
        {
            User32.DestroyIcon(handle);
        }
    }
}
