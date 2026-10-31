// System notifications for new messages through Lomiri's Postal service
// (needs the "push-notification-client" AppArmor policy group). Lomiri
// suspends apps in the background, so these only appear while the app is
// allowed to run - see the README.

#ifndef NOTIFIER_H
#define NOTIFIER_H

#include <QString>

class Notifier
{
public:
    // title: the conversation; sender: who wrote it in a group ("" in a
    // one-to-one chat); text: "" for messages with only attachments.
    void notify(const QString &title, const QString &sender, const QString &text) const;

private:
    static QString appId();
};

#endif
