// Reads the contact the Contacts app hands over through the Content Hub
// (a vCard file): its name and phone numbers.

#ifndef VCARD_H
#define VCARD_H

#include <QString>
#include <QStringList>

struct VCardContact {
    QString name;
    QStringList numbers;
};

// Reads the first contact of a vCard file. The file is removed afterwards:
// it is the app's copy in HubIncoming and not needed any more.
VCardContact readVCardFile(const QString &path);

// The first contact of vCard text (versions 2.1, 3.0 and 4.0).
VCardContact parseVCard(const QByteArray &data);

#endif
