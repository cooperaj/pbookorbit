#include <QSignalSpy>
#include <QTest>

#include "core/booklistmodel.h"

// QSignalSpy records each emission of one signal, with its arguments, so a test can check
// that the model told its views the right thing.
class TestBookListModel : public QObject
{
    Q_OBJECT

    static QVariantMap bookNamed(const QString &title)
    {
        return {{"id", 1}, {"title", title}};
    }

private slots:
    // A list knows its length before any books arrive, so the scrollbar is right from the
    // start
    void newListShowsBlankRowsForEveryBook()
    {
        BookListModel model;
        QSignalSpy resets(&model, &QAbstractItemModel::modelReset);

        model.reset(3);

        QCOMPARE(resets.count(), 1);
        QCOMPARE(model.rowCount(), 3);
        QVERIFY(!model.isLoaded(0));
        const QVariantMap row = model.data(model.index(0), Qt::UserRole + 1).toMap();

        // these three are needed for a "loading" BookRow to render without error
        QCOMPARE(row.value("loaded"), false);
        QCOMPARE(row.value("id"), -1);
        QCOMPARE(row.value("hidden"), false);
        QVERIFY(model.book(0).isEmpty());
    }

    // Only the rows the page covers change and redraw
    void arrivingPageFillsOnlyItsRows()
    {
        BookListModel model;
        model.reset(4);
        QSignalSpy changes(&model, &QAbstractItemModel::dataChanged);

        model.setBooks(1, {bookNamed("A"), bookNamed("B")});

        QCOMPARE(changes.count(), 1);
        QCOMPARE(changes.first().at(0).toModelIndex().row(), 1);
        QCOMPARE(changes.first().at(1).toModelIndex().row(), 2);
        QVERIFY(!model.isLoaded(0));
        QVERIFY(model.isLoaded(1));
        QVERIFY(model.isLoaded(2));
        QVERIFY(!model.isLoaded(3));
        QCOMPARE(model.book(1).value("title"), "A");
        QCOMPARE(model.book(1).value("loaded"), true);
    }

    // A page can arrive after the list has shrunk
    void pageBeyondTheListIsIgnored()
    {
        BookListModel model;
        model.reset(2);
        QSignalSpy changes(&model, &QAbstractItemModel::dataChanged);

        model.setBooks(1, {bookNamed("A"), bookNamed("B"), bookNamed("C")});
        QCOMPARE(model.rowCount(), 2);
        QCOMPARE(model.book(1).value("title"), "A");
        QCOMPARE(changes.count(), 1);

        model.setBooks(-1, {bookNamed("X")});
        QCOMPARE(changes.count(), 1);
        QVERIFY(!model.isLoaded(0));
    }

    // When the total changes, rows are added or removed at the end and the loaded books stay
    void changedTotalKeepsLoadedBooks()
    {
        BookListModel model;
        model.reset(2);
        model.setBooks(0, {bookNamed("A"), bookNamed("B")});
        QSignalSpy inserts(&model, &QAbstractItemModel::rowsInserted);
        QSignalSpy removes(&model, &QAbstractItemModel::rowsRemoved);

        model.resize(5);
        QCOMPARE(model.rowCount(), 5);
        QCOMPARE(inserts.count(), 1);
        QCOMPARE(inserts.first().at(1).toInt(), 2);
        QCOMPARE(inserts.first().at(2).toInt(), 4);
        QCOMPARE(model.book(1).value("title"), "B");
        QVERIFY(!model.isLoaded(4));

        model.resize(1);
        QCOMPARE(model.rowCount(), 1);
        QCOMPARE(removes.count(), 1);
        QCOMPARE(removes.first().at(1).toInt(), 1);
        QCOMPARE(removes.first().at(2).toInt(), 4);
        QCOMPARE(model.book(0).value("title"), "A");

        model.resize(1);
        QCOMPARE(inserts.count(), 1);
        QCOMPARE(removes.count(), 1);
    }

    // Each redraw is a slow e-ink update, so nothing is sent when nothing changed
    void changingABookRedrawsOnlyItsRow()
    {
        BookListModel model;
        model.reset(2);
        model.setBooks(0, {bookNamed("A")});
        QSignalSpy changes(&model, &QAbstractItemModel::dataChanged);

        model.setField(0, "title", "B");
        QCOMPARE(changes.count(), 1);
        QCOMPARE(changes.first().at(0).toModelIndex().row(), 0);
        QCOMPARE(changes.first().at(1).toModelIndex().row(), 0);
        QCOMPARE(model.book(0).value("title"), "B");

        // Neither the same value again nor a row that isn't loaded is a change
        model.setField(0, "title", "B");
        model.setField(1, "title", "C");
        QCOMPARE(changes.count(), 1);
        QVERIFY(!model.isLoaded(1));
    }
};

QTEST_GUILESS_MAIN(TestBookListModel)
#include "tst_booklistmodel.moc"
