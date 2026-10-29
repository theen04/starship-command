"""Starship Command web server.

A thin HTTP layer over the game engine, which lives entirely in PostgreSQL
(see db/init/03_functions.sql). Each game route calls one database function
and returns its JSON document unchanged: {"ok", "message", "state", ...}.
"""

import logging
import os

import psycopg
from flask import Flask, jsonify, render_template, request
from psycopg import sql

DATABASE_URL = os.environ.get(
    "DATABASE_URL", "postgresql://starship:starship@localhost:5432/starship_command"
)
MAX_INT = 2**31 - 1  # ids are Postgres INT columns

app = Flask(__name__)
log = logging.getLogger(__name__)


def call(function, *args):
    """Run SELECT function(args...) and return its single (JSONB) value."""
    query = sql.SQL("SELECT {}({})").format(
        sql.Identifier(function),
        sql.SQL(", ").join(sql.Placeholder() * len(args)),
    )
    with psycopg.connect(DATABASE_URL, autocommit=True) as conn:
        return conn.execute(query, args).fetchone()[0]


def not_found():
    return jsonify(ok=False, message="Player not found.", state=None), 404


def bad_request(message):
    return jsonify(ok=False, message=message, state=None), 400


def play(function, player_id, *args):
    """Call a gameplay function; a null state means the player does not exist."""
    if not 0 < player_id <= MAX_INT:
        return not_found()
    result = call(function, player_id, *args)
    if result["state"] is None:
        return not_found()
    return jsonify(result)


def body():
    return request.get_json(silent=True) or {}


@app.get("/")
def index():
    return render_template("index.html")


@app.get("/healthz")
def healthz():
    with psycopg.connect(DATABASE_URL) as conn:
        conn.execute("SELECT 1")
    return jsonify(ok=True)


@app.post("/api/players")
def create_player():
    username = body().get("username")
    if not isinstance(username, str):
        return bad_request("A callsign is required.")
    result = call("usp_create_player", username)
    if not result["ok"]:
        return jsonify(result), 400
    return jsonify(result), 201 if result["is_new"] else 200


@app.get("/api/players/<int:player_id>")
def get_state(player_id):
    if not 0 < player_id <= MAX_INT:
        return not_found()
    state = call("fn_game_state", player_id)
    if state is None:
        return not_found()
    return jsonify(ok=True, message=None, state=state)


@app.post("/api/players/<int:player_id>/look")
def look(player_id):
    return play("usp_look_around", player_id)


@app.post("/api/players/<int:player_id>/move")
def move(player_id):
    direction = body().get("direction")
    if not isinstance(direction, str):
        return bad_request("A direction is required.")
    return play("usp_move_player", player_id, direction)


@app.post("/api/players/<int:player_id>/pickup")
def pick_up(player_id):
    item_id = body().get("item_id")
    if type(item_id) is not int or not 0 < item_id <= MAX_INT:
        return bad_request("A valid item_id is required.")
    return play("usp_pick_up_item", player_id, item_id)


@app.post("/api/players/<int:player_id>/inventory")
def inventory(player_id):
    return play("usp_show_inventory", player_id)


@app.post("/api/players/<int:player_id>/complete")
def complete(player_id):
    return play("usp_complete_game", player_id)


@app.post("/api/players/<int:player_id>/restart")
def restart(player_id):
    return play("usp_restart_game", player_id)


@app.get("/api/players/<int:player_id>/log")
def action_log(player_id):
    if not 0 < player_id <= MAX_INT:
        return not_found()
    limit = request.args.get("limit", default=25, type=int)
    return jsonify(call("fn_action_log", player_id, limit))


@app.errorhandler(psycopg.Error)
def database_error(error):
    log.exception("Database error", exc_info=error)
    return jsonify(ok=False, message="The ship's computer is not responding.", state=None), 503
