from app.logx import log

SEVERITY = {True: "error", False: "info"}


def build(rows):
    failed = [r for r in rows if r.get("failed")]
    log.emit(SEVERITY[bool(failed)], "report built", n=len(rows), failed=len(failed))
    return {"rows": len(rows), "failed": len(failed)}
