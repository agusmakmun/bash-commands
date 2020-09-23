# This method if the files has no extentions.
$ for file in *; do mv "$file" "$file.png"; done

# This method if the files has extentions before.
$ for file in *.jpg; do mv "$file" "$file.png"; done
