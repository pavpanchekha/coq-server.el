
Coq Server Emacs Support
========================

This Elisp library makes it easy to do your Coq development on a remote machine.

**Why**: Coq is slow and needs a beefy machine with a good CPU. Buy one for your lab and timeshare.

**How**: `coq-server.el`, with some SSH, `sshfs`, and Tramp.


Installing
----------

Clone this repository. And build the `dpipe` binary with `make`.

Ensure that you can log in to the Coq server without giving a password (public key authentication),
that the server has Coq and `sshfs` installed and that your user can use it,
and that different users' files aren't visible to each other by default.

Open up Emacs and load the `coq-server.el` file with `M-x load-file`.
Run `M-x customize-group coq-server`.
You'll want to edit all the variables here.
Be particularly careful to set the local dpipe variable to point to the `dpipe` binary you built.


Using
-----

Now open up a Coq file and hit `C-c r`.
If everything goes well (and it might not),
Coq should suddenly be much faster.
