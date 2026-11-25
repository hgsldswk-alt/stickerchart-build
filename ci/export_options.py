"""Render signing options for the app and its widget."""
import os
from pathlib import Path
import plistlib
import sys

data = plistlib.loads(Path(__file__).with_name("ExportOptions.plist").read_bytes())
data["teamID"] = os.environ["TEAM_ID"]
app_id = os.environ.get("APP_ID", "com.hgsldswk.stickerchart")
data["provisioningProfiles"] = {
    app_id: os.environ.get("APP_PROFILE", "StickerChart AppStore"),
    app_id + ".widget": os.environ.get("WIDGET_PROFILE", "StickerChart Widget AppStore"),
}
sys.stdout.buffer.write(plistlib.dumps(data))
