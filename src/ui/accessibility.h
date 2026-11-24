#pragma once

#include <QObject>
#include <QString>

// The system's text settings (Settings > Accessibility > Text & contrast), for QML as
// accessibility, applied as the firmware's own Qt apps apply them (see StyledText.qml).
class Accessibility : public QObject
{
    Q_OBJECT
    // Text size, 1 to 2
    Q_PROPERTY(qreal textScale READ textScale NOTIFY changed)
    // All text bold
    Q_PROPERTY(bool boldText READ boldText NOTIFY changed)
    // Grey text drawn black
    Q_PROPERTY(bool highContrast READ highContrast NOTIFY changed)
    // The system font, OpenDyslexic if the user chose it
    Q_PROPERTY(QString fontFamily READ fontFamily NOTIFY changed)

public:
    explicit Accessibility(QObject *parent = nullptr);

    // Reads the settings again when the system says they've changed. Call after the
    // platform plugin has started.
    void followChanges();
    // Reads the settings
    Q_INVOKABLE void reload();

    qreal textScale() const { return m_textScale; }
    bool boldText() const { return m_boldText; }
    bool highContrast() const { return m_highContrast; }
    QString fontFamily() const { return m_fontFamily; }

signals:
    void changed();

private:
    qreal m_textScale = 1;
    bool m_boldText = false;
    bool m_highContrast = false;
    QString m_fontFamily;
};
