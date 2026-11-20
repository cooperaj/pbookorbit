#include "core/listfilter.h"
#include "core/database.h"
#include "core/session.h"

ListFilter::ListFilter(Session *session, Database *database, QObject *parent)
    : QObject(parent)
    , m_database(database)
{
    // Saved as what's hidden, so a missing setting shows everything
    m_ebooks = !m_database->flag("hideEbooks");
    m_audiobooks = !m_database->flag("hideAudiobooks");
    m_downloadedOnly = m_database->flag("downloadedOnly");

    // The next user starts with everything
    connect(session, &Session::signedOut, this, [this]() {
        if (m_ebooks && m_audiobooks && !m_downloadedOnly)
            return;
        m_ebooks = true;
        m_audiobooks = true;
        m_downloadedOnly = false;
        save();
    });
}

void ListFilter::showContent(const QString &kind, bool on)
{
    bool &shown = kind == "ebook" ? m_ebooks : m_audiobooks;
    const bool other = kind == "ebook" ? m_audiobooks : m_ebooks;
    if (shown == on || (!on && !other))
        return;
    shown = on;
    save();
}

void ListFilter::setDownloadedOnly(bool on)
{
    if (on == m_downloadedOnly)
        return;
    m_downloadedOnly = on;
    save();
}

void ListFilter::save()
{
    m_database->setFlag("hideEbooks", !m_ebooks);
    m_database->setFlag("hideAudiobooks", !m_audiobooks);
    m_database->setFlag("downloadedOnly", m_downloadedOnly);
    emit changed();
}
