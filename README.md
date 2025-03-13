[Русская версия](./README.ru.md)

# CDR Archiver

**CDR Archiver** is a Bash script designed to automate the archiving of CDR (Call Detail Records) files. It groups files by month, compresses them into archives, and deletes the original files after successful archiving. Logs of all actions are saved in the `archive_log.txt` file. The script supports flexible configuration via command-line parameters, including specifying the source directory, archive directory, and file name pattern. It is ideal for handling large volumes of data in telecommunications systems.

This is a **personal project** created to solve a specific task. 

## Features
1. **Groups files by month**:
   - The script analyzes file names (e.g., `cdr_20051001_123456_ROOT.csv`) and determines which month they belong to.

2. **Creates archives**:
   - Files from the same month are packed into an archive named in the format `folder_name_YEAR_MONTH.tar.gz`. For example, if the source folder is named `call_logs`, the archive will be named `call_logs_2005_10.tar.gz`.

3. **Deletes original files**:
   - After successful archiving, the original files are deleted to free up space.

4. **Logs actions**:
   - All actions are logged in the `archive_log.txt` file, which is created in the archive directory.

5. **Checks free disk space**:
   - Before archiving, the script checks if there is enough disk space.

## System Requirements
- **Operating System**: Linux.
- **Utilities**: `bash`, `tar`, `find`, `awk`, `du`, `df`.

## Installation
1. Clone the repository:
```bash
git clone https://github.com/SkyrocketStan/cdr-archiver.git
cd cdr-archiver
```

2. Make the script executable:
```bash
chmod +x cdr_archiver.sh
```

## Usage

### 1. Using named parameters
```bash
./cdr_archiver.sh --source-dir /path/to/source --archive-dir /path/to/archives --pattern "cdr_*_*.csv"
```

### 2. Using positional arguments
```bash
./cdr_archiver.sh /path/to/source /path/to/archives "cdr_*_*.csv"
```

### 3. Help
```bash
./cdr_archiver.sh --help
```

## Parameters
| Parameter          | Description                                                                 |
|-------------------|-------------------------------------------------------------------------|
| `--source-dir`    | Directory containing the source CDR files.                              |
| `--archive-dir`   | Directory where archives will be saved.                                 |
| `--pattern`       | File name pattern (default: `cdr_*_*.csv`).                            |
| `--help`          | Displays help information.                                              |

## Logging
The script creates a log file `archive_log.txt` in the archive directory. Example log:
```
2005-10-25 12:34:56 - Success: Created archive call_logs_2005_10.tar.gz with 150 files.
2005-10-25 12:34:57 - Error: Failed to create archive call_logs_2005_09.tar.gz.
2005-10-25 12:35:00 - Script completed.
```

## How It Works
- **Batch archiving**: Files are grouped by month and archived in a single command.
- **Parallel processing**: If there are many files, data for different months can be archived simultaneously.
- **Free space check**: The script checks for sufficient disk space before archiving.

## License
This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

## Author
- **Stanislav Rakitov**  

## Contributing
If you have ideas for improvement, feel free to create an Issue or submit a Pull Request. All contributions are welcome!

## Links
- [Issues](https://github.com/SkyrocketStan/cdr-archiver/issues)  
- [Releases](https://github.com/SkyrocketStan/cdr-archiver/releases)  
- [Wiki](https://github.com/SkyrocketStan/cdr-archiver/wiki)  
