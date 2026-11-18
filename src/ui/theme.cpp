#include "ui/theme.h"
#include "core/database.h"
#include "core/diagnostics.h"
#include "core/session.h"
#include "ui/accents.h"
#include "ui/einkcolors.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <algorithm>

Theme::Theme(Session *session, Database *database, QObject *parent)
    : QObject(parent)
    , m_session(session)
    , m_database(database)
{
    m_accent = m_database->text("accent");

    // It belongs to the signed-out user
    connect(m_session, &Session::signedOut, this, [this]() {
        m_accent.clear();
        m_database->remove("accent");
        emit accentChanged();
    });
}

QColor Theme::accentColor() const
{
    // Saturated for e-ink, like the covers
    return einkColor(accentColors(m_accent).color);
}

QColor Theme::accentTextColor() const
{
    return accentColors(m_accent).text;
}

void Theme::load()
{
    // {settings: {theme, accent, ...}}, or {settings: null} if the user has never synced
    // their theme. Quiet, since the colour isn't urgent.
    m_session->download("/user-preferences/theme",
        [this](const QByteArray &data) {
            const QString accent = QJsonDocument::fromJson(data).object().value("settings")
                                       .toObject().value("accent").toString();
            diagnostics::log("accent: " + (accent.isEmpty() ? QString("default") : accent));
            if (accent == m_accent)
                return;
            m_accent = accent;
            m_database->setText("accent", m_accent);
            emit accentChanged();
        },
        [](int, const QString &message) { diagnostics::log("accent: " + message); });
}

// Like the web client's authorInitials(): first letters of the first and last words,
// ignoring anything in brackets and handling "Surname, Forename"
static QString authorInitials(const QString &name)
{
    static const QRegularExpression brackets("\\(.*?\\)");
    static const QRegularExpression punctuation("[^\\p{L}\\p{N}\\s.'-]");
    static const QRegularExpression spaces("\\s+");
    static const QRegularExpression letter("\\p{L}");
    QString ordered = QString(name).replace(brackets, " ");
    if (ordered.contains(',')) {
        QStringList parts = ordered.split(',');
        std::reverse(parts.begin(), parts.end());
        ordered = parts.join(' ');
    }
    ordered = ordered.replace(punctuation, " ").trimmed();
    QStringList letters;
    for (const QString &word : ordered.split(spaces, Qt::SkipEmptyParts)) {
        const QRegularExpressionMatch match = letter.match(word);
        if (match.hasMatch())
            letters.append(match.captured());
    }
    if (letters.isEmpty())
        return "?";
    return (letters.first() + (letters.size() > 1 ? letters.last() : QString())).toUpper();
}

QVariantMap Theme::authorMonogram(const QString &name) const
{
    const CoverPalette palette = coverPalette(name, m_accent);
    return QVariantMap{
        {"initials", authorInitials(name)},
        {"from", einkColor(palette.from)},
        {"to", einkColor(palette.to)},
        {"color", palette.text},
    };
}
