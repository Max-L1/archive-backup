#!/usr/bin/bash

tar_and_encrypt () {
  file=$1
  file_basename=`basename "$file"`
  backup_dirname=`dirname "$file"`
  password=$2
  rng_filename=$(cat /dev/urandom | head -c 10 | md5sum | awk '{print $1}')
  backup_output_dir=$3

  if [[ "$file" == *.tar ]]; then
    echo "$file is already a tar file, skipping tar step"
    cp "$file" "$backup_output_dir/$rng_filename.tar"
  else 
    echo "Making tar for $file"
    tar -cf "$backup_output_dir/$rng_filename.tar" -C "$backup_dirname" "$file_basename"
  fi

  tar_size_bytes=`du $backup_output_dir/$rng_filename.tar -b | awk '{print $1}'`
  echo "Encrypting $file"
  gpg --no-tty --yes --cipher-algo aes256 -c --no-symkey-cache --passphrase $password --pinentry-mode loopback "$backup_output_dir/$rng_filename.tar"
  # output to seperate file then combine at end to avoid potential parallel write issues
  echo "{\"$rng_filename\":{\"original_name\":\"$file_basename\",\"tar_size_bytes\":$tar_size_bytes,\"tar_hash_md5\": \"`md5sum $backup_output_dir/$rng_filename.tar | awk '{print $1}'`\", \"tar_hash_sh256\": \"`sha256sum $backup_output_dir/$rng_filename.tar | awk '{print $1}'`\"}}" > $backup_output_dir/$rng_filename.json.tmp

  echo "\"$file_basename\" - $rng_filename.tar" >> $backup_output_dir/$rng_filename.txt.tmp
  rm "$backup_output_dir/$rng_filename.tar"
}

while [ $# -gt 0 ]; do
    if [[ $1 == "--"* ]]; then
        v="${1/--/}"
        declare "$v"="$2"
        shift
    fi
    shift
done

if [ -z "$backup" ]
  then 
  echo "Need to supply directory to backup with --backup"
  exit 0
fi

echo "###############################################################"
echo "##### Supplying ecryption password as text is insecure    #####" 
echo "##### and can be read by other users on the system easily #####"
echo "##### (e.g. with 'ps aux | grep gpg')                     #####"
echo "##### To continue confirm by typing 'I understand'        #####"
echo "##### Future versions will allow passing password as file #####"
echo "###############################################################"	
read confirmation

while [ "$confirmation" != "I understand" ]
do
  echo "Please type 'I understand' to continue"
  read confirmation
done

read -sp "Encryption password:" password1
echo ""

read -sp "Retype encryption password:" password2
echo ""

if [ $password1 != $password2 ]
then
  echo -e "Passwords don't match\n"
  exit 0
fi	

read -sp "And once more for good luck:" password3
echo ""

if [ $password2 != $password3 ]
then
  echo "Passwords don't match"
  exit 0
fi	

datetime=`date +"%Y-%m-%d_%H-%M-%S"`
backup_output_dir=backup_$datetime

export -f tar_and_encrypt
mkdir -p $backup_output_dir

# Save metadata on file contents (encrypted)
tree -a $backup -sh -H http://localhost -o "$backup_output_dir/tree_output_$datetime.html"
gpg --no-tty --yes --cipher-algo aes256 -c --no-symkey-cache --passphrase $password1 --pinentry-mode loopback "$backup_output_dir/tree_output_$datetime.html"
rm "$backup_output_dir/tree_output_$datetime.html"

find $backup -type f -printf "%p %sB\n" > "$backup_output_dir/find_output_$datetime.txt"
gpg --no-tty --yes --cipher-algo aes256 -c --no-symkey-cache --passphrase $password1 --pinentry-mode loopback "$backup_output_dir/find_output_$datetime.txt"
rm "$backup_output_dir/find_output_$datetime.txt"

ls $backup | parallel --line-buffer -I% tar_and_encrypt "$backup/%" $password1 $backup_output_dir

# Append all json files and encrypt
jq -s '.' $backup_output_dir/*.json.tmp > $backup_output_dir/filenames_$datetime.json
rm $backup_output_dir/*.json.tmp
gpg --no-tty --yes --cipher-algo aes256 -c --no-symkey-cache --passphrase $password1 --pinentry-mode loopback "$backup_output_dir/filenames_$datetime.json"
rm "$backup_output_dir/filenames_$datetime.json"

# Append all txt files and encrypt
cat $backup_output_dir/*.txt.tmp > $backup_output_dir/filenames_$datetime.txt
rm $backup_output_dir/*.txt.tmp
gpg --no-tty --yes --cipher-algo aes256 -c --no-symkey-cache --passphrase $password1 --pinentry-mode loopback "$backup_output_dir/filenames_$datetime.txt"
rm "$backup_output_dir/filenames_$datetime.txt"
