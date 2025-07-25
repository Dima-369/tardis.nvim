.. image:: ./assets/tardis.webp

Fork changes
============

- buffer name now includes the git commits relative time to now
- revision message is now nicely shown in a floating window
- new revision picker using fzf-lua to quickly jump to any revision

Original README
===============

Tardis allows you to travel in time (git history) scrolling through each
revision of your current file.

Inspired by
`git-timemachine <https://github.com/emacsmirror/git-timemachine>`__
which I used extensively when I was using emacs.

Installation
============

Like with any other

.. code:: lua

   {
       'fredeeb/tardis.nvim',
       dependencies = { 'nvim-lua/plenary.nvim' },
       config = true,
   }

The default options are

.. code:: lua

    require('tardis-nvim').setup {
        keymap = {
            ["next"] = '<C-j>',             -- next entry in log (older)
            ["prev"] = '<C-k>',             -- previous entry in log (newer)
            ["quit"] = 'q',                 -- quit all
            ["revision_message"] = '<C-m>', -- show revision message for current revision
            ["commit"] = '<C-g>',           -- replace contents of origin buffer with contents of tardis buffer
            ["revision_picker"] = '<C-p>',  -- show fzf-lua picker to jump to any revision
        },
        initial_revisions = 10,             -- initial revisions to create buffers for
        max_revisions = 256,                -- max number of revisions to load
    }

Usage
=====

Using tardis is pretty simple

::

   :Tardis <adapter>

This puts you into a new buffer where you can use the keymaps, like
described above, to navigate the revisions of the currently open file

List of currently supported adapters:

* git

Known issues
============

See |issues|

Contributing
============

Go ahead :)

.. |issues| image:: https://github.com/FredeEB/tardis.nvim/issues
