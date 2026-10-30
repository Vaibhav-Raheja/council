import app.logx as L


def main(argv):
    # legacy_log is mentioned in this comment on purpose; comments may stay as they are.
    L.log.emit("info", "cli start", argv=list(argv))
    return 0
