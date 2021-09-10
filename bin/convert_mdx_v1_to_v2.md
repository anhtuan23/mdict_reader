# Steps to convert mdict files v1 to v2

Using [mdict-utils](https://github.com/liuyug/mdict-utils)

1. Install mdict-uitls

   pip install mdict-utils

2. Check metadata of mdict file

   mdict -m dict.mdx

3. Unpack mdict file to `mdx` folder

   mdict -x dict.mdx -d ./mdx

4. Repack mdict file from `mdx` folder

   mdict --title title.html --description description.html -a dict.txt dict.mdx
