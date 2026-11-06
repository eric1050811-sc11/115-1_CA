#!/bin/bash
# Step 1: copy Part 1 and rename files

rsync -av --exclude=setup.sh ../riscvssc_part1/ .

for file in *; do
  if [[ "$file" == *riscvssc_part1* ]]; then
    mv "$file" "${file/riscvssc_part1/riscvssc_part2}"
  fi
done

# Step 2: replace inside files
for file in *; do
  [ "$file" = "setup.sh" ] && continue
  [ -f "$file" ] || continue
  if [ "$(uname)" = "Darwin" ]; then
    sed -i '' 's/riscvssc_part1/riscvssc_part2/g' "$file"
  else
    sed -i 's/riscvssc_part1/riscvssc_part2/g' "$file"
  fi
done
