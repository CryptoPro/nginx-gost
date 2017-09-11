vim_local_conf="
runtime! debian.vim\n
\n
if has(\"syntax\")\n
  syntax on\n
endif\n
\n
set tabstop=4\n
set shiftwidth=4\n
set smarttab\n
set expandtab\n
set smartindent\n"

echo ${vim_local_conf} >> /etc/vim/vimrc.local
