# q-backup-manager

A modular and smart Bash-based backup automation tool built for the Amazon Q Developer "Quack The Code" Challenge.

## Features

- Full or partial backups
- Scheduled backups using `cron`
- Dry-run mode
- Logging with color-coded outputs
- Modular Bash code for easier maintenance

## Requirements

- Bash 4.x+
- `tar`, `rsync`, `cron`

## Installation

```bash
git clone https://github.com/puru54/q-backup-manager.git
cd q-backup-manager
chmod +x backup.sh
```

## Usage

### Full Backup

```bash
./backup.sh --full
```

### Project Directory Backup

```bash
./backup.sh --project /path/to/your/project
```

### Dry Run

```bash
./backup.sh --dry-run --project /path/to/your/project
```

### Schedule with Cron

To run daily at midnight:

```bash
crontab -e
```

Add:

```bash
0 0 * * * /full/path/to/backup.sh --full >> /var/log/q-backup.log 2>&1
```

## License

MIT
