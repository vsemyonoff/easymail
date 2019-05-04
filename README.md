## EasyMail

Contents:
1. [Overview](#overview)
1. [Setup](#setup)
1. [Usage](#usage)
1. [Configuration](#configuration)
1. [Implementation details](#imaplementation-details)
   1. [mbsync config](#mbsync)
   1. [notmuch config](#notmuch-config)
   1. [IMAP IDLE notifications](#imap-idle-notifications)
   1. [pass and systemd](#pass-and-systemd)
   1. [systemd user service](#systemd-user-service)
   1. msmtp config - TODO

### Overview
This set of scripts is a **glue** between [mbsync](http://isync.sourceforge.net/), [notmuch](https://notmuchmail.org),
ZX2C4 [password-storage](https://www.passwordstore.org) and [goimapnotify](https://gitlab.com/shackra/goimapnotify) IMAP
notification daemon.

Main goal is to provide offline mail system with continious new mail delivery without network overhead and delays. That
means that I want to pull mail from server only when there are _new_ messages and push back only _changed_ IMAP
folders. First goal achieved with **goimapnotify** daemon which monitors specified in it's config IMAP folders and
triggers external commands on new events, the second one achieved with **mbsync** tool from **isync** package which
syncronize changes between IMAP server and local storage. For new mail indexing I've chose **notmuch** becase:
* it's ultra fast;
* easy to use;
* present in Arch's community repo (no need to compile);
* natively integrates with Emacs.

I'm using Emacs for mail reading but **EasyMail** is mail reader agnostic and will work in background without any MUA at
all, supposed that user can use any that supports **notmuch**.

There are a lot of blogs/articles in network like _'My perfect mail setup'_ and each author thying to implement
something new. So [here](https://github.com/vsemyonoff/easymail) I've tried to join all found information together.

### Setup
Copy ```easymail``` script somewhere in ```PATH```, ```easymail@.service``` in ```~/${XDG_CONFIG_HOME}/systemd/user```,
and ```easymail-{pre,post}-new.sh``` to ```${MAILDIR}/.notmuch/hooks/{pre,post}-new```. Script depends on 3-rd party
tools described above.

**Note**: for Gmail accounts ```All Mail``` folder ```Show in IMAP``` should be unchecked in ```Lables``` menu, unchecked in
Lables settings menu. Pre-new _notmuch_ hook hanles _move to trash_ messages tagged as "+trashed" and to work propery
both with Fastmail and Gmail the last one shoul set ```Auto-Expunge -> off``` and ```Immediately delete the message forever```
in ```Forwarding POP/IMAP``` settings menu.

### Usage
```bash
➤ easymail help
usage: 'command'

Supported commands:
    disable   - stop account syncronization using IMAP IDLE,
    enable    - start account syncronization using IMAP IDLE,
    get       - get account information,
    help      - internal commands help,
    index     - index mailbox with 'notmuch'
    list      - list configured accounts,
    remove    - remove account,
    setup     - setyp new mail account,
    status    - show account status,
    sync      - sync account with remote server.

Try 'easymail help command' to see 'command' help.

➤ easymail help setup
usage: setup [--enable] [--full-name=name] [--port=port] [--server=server] 'account' 'email' 'pass'

Setup and optionally enable 'account' for 'email' with 'pass' password.
    --enable     - start new email polling just after setup,
    --full-name= - use non-default full user name,
    --port=      - use non standard IMAP port (default: 993),
    --server=    - use custom IMAP server.

Server name will be extracted from email address, newly created account will be disabled
after setup, full user name will be taken from global 'notmuch' configuration.

'pass' file should contain 'app-pass' field.

Use: easymail enable 'account' to start new mail polling or specify '--enable' above.

```

Example 1: I need to setup my work email ```Vasya Petelkin <vpetelkin@megacorp.com>```
```bash
➤ easymail setup Megacorp vpetelkin@megacorp.com work/megacorp
```

This will produce four files: ```${XDG_CONFIG_HOME}/easymail/{mbsync,notify,notmuch}.conf```
and ```${PASSORD_STORE_DIR}/.easymail/Megacorp.gpg``` relative symlink to ```${PASSWORD_STORE_DIR}/work/megacorp.gpg```.
Since ```${PASSORD_STORE_DIR}/.easymail``` is hidded it will be invisible for regular ```pass``` command
and ```browserpass``` browser extension.

Script will discover _all_ IMAP folders on server '_imap.megacorp.com_' and put them into '_mbsync.conf_' and
'_notify.conf_'.

**Note**: pass file should contain application password field named 'app-pass' (fild name may be changed in config),
account name should NOT contain spaces.


Example 2: Like (1) but enable messages polling just after setup:
```bash
➤ easymail setup --enable Megacorp vpetelkin@megacorp.com work/megacorp
```

Example 3: If email does not mutch IMAP server (for example corporate email hosted on Gmail):
```bash
➤ easymail setup --enable --server=imap.gmail.com Megacorp vpetelkin@megacorp.com work/megacorp
```

All three examples will use **default** full user name from global _notmuch_ configuration, if need to set it to
different then provide ```--full-name="Vasiliy Petelkin"``` to ```easymail``` script.

**Note**: if using non-default ```GNUPGHOME``` and/or ```PASSWORD_STORAGE_DIR``` then need to
create  ```~/.profile.d/env.d/user.env``` with proper values or update provided systemd service and set them there.
I did the first with [my bash profile](https://github.com/vsemyonoff/dotfiles/blob/master/.profile).
