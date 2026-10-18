using System.Drawing.Drawing2D;

namespace VoiceNotes.Windows.Views;

internal static class RoundedRectangles
{
    internal static GraphicsPath Capsule(RectangleF bounds) =>
        Rounded(bounds, Math.Min(bounds.Width, bounds.Height) / 2);

    internal static GraphicsPath Rounded(RectangleF bounds, float radius)
    {
        var diameter = radius * 2;
        var path = new GraphicsPath();
        path.AddArc(bounds.Left, bounds.Top, diameter, diameter, 180, 90);
        path.AddArc(bounds.Right - diameter, bounds.Top, diameter, diameter, 270, 90);
        path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(bounds.Left, bounds.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }
}
