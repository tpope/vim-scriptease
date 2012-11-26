# scriptease.vim

Enjoy this amalgamation of crap I use for editing runtime files.

* `:PP`: Pretty print.
* `:Runtime`: Reload runtime files.  Like `:runtime!`, but it unlets any
  include guards first.
* `:Scriptnames`: Load `:scriptnames` into the quickfix list.
* `:Verbose`: Capture the output of a `:verbose` invocation into the preview
  window.
* `:Vedit`: Edit a file found in the runtime path. (Also, ':Vsplit',
  ':Vtabedit', etc.) Extracted from
  [pathogen.vim](https://github.com/tpope/vim-pathogen).
* `K`: Look up the `:help` for the VimL construct under the cursor.
* `zS`: Show the active syntax highlighting groups under the cursor.

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
[GitHub](https://github.com/tpope/vim-scriptease). And if
you're feeling especially charitable, follow [tpope](http://tpo.pe/) on
[Twitter](http://twitter.com/tpope) and
[GitHub](https://github.com/tpope).

## License

Copyright (c) Tim Pope.  Distributed under the same terms as Vim itself.
See `:help license`.
