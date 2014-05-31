# scriptease.vim

I make so many Vim plugins I had to make a Vim plugin for making Vim plugins.

## Features

* `:PP`: Pretty print.  With no argument, acts as a REPL.
* `:Runtime`: Reload runtime files.  Like `:runtime!`, but it unlets any
  include guards first.
* `:Disarm`: Remove a runtime file's maps, commands, and autocommands,
  effectively disabling it.
* `:Scriptnames`: Load `:scriptnames` into the quickfix list.
* `:Verbose`: Capture the output of a `:verbose` invocation into the preview
  window.
* `:Time`: Measure how long a command takes.
* `:Breakadd`: Like its lowercase cousin, but makes it much easier to set
  breakpoints inside functions.  Also `:Breakdel`.
* `:Vedit`: Edit a file relative the runtime path. For example,
  `:Vedit plugin/scriptease.vim`. Also, `:Vsplit`, `:Vtabedit`, etc.
  Extracted from [pathogen.vim](https://github.com/tpope/vim-pathogen).
* `K`: Look up the `:help` for the VimL construct under the cursor.
* `zS`: Show the active syntax highlighting groups under the cursor.
* `g!`: Eval a motion or selection as VimL and replace it with the result.
  This is handy for doing math, even outside of VimL.  It's so handy, in fact,
  that it probably deserves its own plugin.
* Projections for
  [projectionist.vim](https://github.com/tpope/vim-projectionist).

See the `:help` for details.

## Installation

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone git://github.com/tpope/vim-scriptease.git

Once help tags have been generated, you can view the manual with
`:help scriptease`.

## Contributing

See the contribution guidelines for
[pathogen.vim](https://github.com/tpope/vim-pathogen#readme).

## Self-Promotion

Like scriptease.vim? Follow the repository on
[GitHub](https://github.com/tpope/vim-scriptease) and vote for it on
[vim.org](http://www.vim.org/scripts/script.php?script_id=4394). And if
you're feeling especially charitable, follow [tpope](http://tpo.pe/) on
[Twitter](http://twitter.com/tpope) and
[GitHub](https://github.com/tpope).

## License

Copyright (c) Tim Pope.  Distributed under the same terms as Vim itself.
See `:help license`.
