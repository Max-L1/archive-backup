# archive-backup
A simple linux cli for creating encrypted backups of files and directories.

# Dependencies
`parallel` and `jq`

Install before use using the relevant package manager for the disto

## Overview
When run on a directory, it will create a tar archive of any subdirectories and encrypt them with aes256 with a given encryption password. Encrypted files and directories will be logged in a json and a txt file along with output from `tree` and `find` to enable checking of structure and files without the need to untar (useful for large directories).

## Usage
The directory to archive and encrypt is provided through `--backup`
```bash
./archive-backup.sh --backup directory_to_backup
```
This will output a datetime stamped directory with the encrypted outputs
## Output
Each file or directory will be encrypted as a gpg file with a randomly generated name (tar files will not be packed into another tar file, they will just be encrypted).

json metadata is stored for each file/directory (also encrypted with the given password) with the key being the random name to enable referencing the original file along with file hashes of the tar file before encryption.

An example json entry is as follows:

```json
"ed629ed2e39266c192e268533af52a17": {
  "original_name": "my_directory",
  "tar_size_bytes": 6387239036,
  "tar_hash_md5": "16b220ecc3d853446a3b2f41ca400c51",
  "tar_hash_sh256": "c90e5bfb224f9262b6964fb4f74dbef0411b7c54cc3943bb4ab15e1cd83f0ac1"
}
``` 

A txt file is also output that links the randomly generated name to the original name more compactly:
```
"my_directory" - ed629ed2e39266c192e268533af52a17.tar
```

## Issues
- The encryption password is passed via stdin which is a security risk if there are any other users on the system as it is extremely easy to monitor the encryption process and see the password in plain text. Future releases will allow storing the password in an appropriately privilege controlled file to address this
- The linux `parallel` tool is used, so if there is one much larger directory or file, the time to run will be determined mostly by the largest directory/file. It is more efficient to have similarly sized directories or files (having many smaller ones won't be too much of an issue, the problem is if there is one or two that are much larger than all others)
