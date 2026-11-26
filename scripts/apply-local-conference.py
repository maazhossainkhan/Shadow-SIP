#!/usr/bin/env python3
"""Strict source patch for Shadow-SIP local 3-way audio on Android/Windows."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SDK = ROOT / "sdk" / "Medut-SDK"
APP = ROOT / "upstream" / "medut-softphone"


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    current = path.read_text(encoding="utf-8")
    if new in current and old not in current:
        return
    found = current.count(old)
    if found != 1:
        raise SystemExit(f"{label}: expected one patch anchor, found {found}: {path}")
    path.write_text(current.replace(old, new, 1), encoding="utf-8", newline="\n")


def patch_sdk() -> None:
    c = SDK / "src/audio/external.c"
    replace_once(c,
"""#include "../core/medut_internal.h" """.rstrip(),
"""#include "../core/medut_internal.h"
#include "../media/mdt_media.h" """.rstrip(), "audio owner lookup")

    media_header = SDK / "src/media/mdt_media.h"
    replace_once(media_header,
"""int mdt_aurecv_alloc(struct mdt_audio_recv **aupp, const struct mdt_config_audio *cfg,
\t\t size_t sampc, uint32_t ptime);""",
"""int mdt_aurecv_alloc(struct mdt_audio_recv **aupp, const struct mdt_config_audio *cfg,
\t\t size_t sampc, uint32_t ptime);
void mdt_aurecv_set_owner(struct mdt_audio_recv *ar, void *owner);
void *mdt_aurecv_owner(const struct mdt_audio_recv *ar);""", "audio owner API")

    aurecv = SDK / "src/media/aureceiver.c"
    replace_once(aurecv,
"""struct mdt_audio_recv {
\tenum aufmt fmt;""",
"""struct mdt_audio_recv {
\tvoid *owner;                  /* parent struct mdt_audio for local mixing */
\tenum aufmt fmt;""", "audio receiver owner field")
    replace_once(aurecv,
"""};\n\n\nstatic void destructor(void *arg)""",
"""};\n\n\nvoid mdt_aurecv_set_owner(struct mdt_audio_recv *ar, void *owner)\n{\n\tif (ar)\n\t\tar->owner = owner;\n}\n\n\nvoid *mdt_aurecv_owner(const struct mdt_audio_recv *ar)\n{\n\treturn ar ? ar->owner : NULL;\n}\n\n\nstatic void destructor(void *arg)""", "audio receiver owner accessors")

    audio = SDK / "src/media/audio.c"
    replace_once(audio,
"""\terr = mdt_aurecv_alloc(&a->aur, &a->cfg, AUDIO_SAMPSZ, ptime);\n\tif (err)\n\t\tgoto out;""",
"""\terr = mdt_aurecv_alloc(&a->aur, &a->cfg, AUDIO_SAMPSZ, ptime);\n\tif (err)\n\t\tgoto out;\n\tmdt_aurecv_set_owner(a->aur, a);""", "attach audio receiver owner")

    replace_once(c,
"""struct mdt_auplay_st {
\tstruct le         le;     /* member of s_playl, newest last */
\tstruct mdt_auplay_prm prm;
\tmdt_auplay_write_h   *wh;
\tvoid             *arg;
};""",
"""struct mdt_auplay_st {
\tstruct le         le;     /* member of s_playl, newest last */
\tstruct mdt_auplay_prm prm;
\tmdt_auplay_write_h   *wh;
\tvoid             *arg;
\tint16_t          *frame;  /* reusable scratch frame for local mixing */
\tsize_t            sampc;
\tstruct aubuf     *crossbuf; /* decoded remote audio for the opposite call */
};""", "playback state")

    replace_once(c,
"""static RE_ATOMIC bool s_ready;
static struct list    s_srcl;    /* struct mdt_ausrc_st  */
static struct list    s_playl;   /* struct mdt_auplay_st */""",
"""static RE_ATOMIC bool s_ready;
static struct list    s_srcl;       /* struct mdt_ausrc_st  */
static struct list    s_playl;      /* struct mdt_auplay_st */
static bool           s_conference; /* guarded by s_lock */""", "conference flag")

    replace_once(c,
"""static size_t nsamp_for(uint32_t srate, uint8_t ch, uint32_t ptime)
{
\treturn (size_t)srate * ch * (ptime ? ptime : 20) / 1000;
}""",
"""static size_t nsamp_for(uint32_t srate, uint8_t ch, uint32_t ptime)
{
\treturn (size_t)srate * ch * (ptime ? ptime : 20) / 1000;
}

static uint32_t normal_ptime(uint32_t ptime)
{
\treturn ptime ? ptime : 20;
}

static bool same_audio_format(int fmt_a, uint32_t rate_a, uint8_t ch_a,
                               uint32_t ptime_a, int fmt_b, uint32_t rate_b,
                               uint8_t ch_b, uint32_t ptime_b)
{
\treturn fmt_a == fmt_b && rate_a == rate_b && ch_a == ch_b &&
\t       normal_ptime(ptime_a) == normal_ptime(ptime_b);
}

/* Called with s_lock held. Only two full-duplex, identically negotiated
 * S16LE legs can enter the local mixer. */
static bool conference_format_valid_locked(void)
{
\tstruct mdt_ausrc_st *src[2] = {NULL, NULL};
\tstruct mdt_auplay_st *play[2] = {NULL, NULL};
\tstruct le *le;
\tunsigned ns = 0, np = 0;

\tfor (le = list_head(&s_srcl); le; le = le->next) {
\t\tif (ns >= 2)
\t\t\treturn false;
\t\tsrc[ns++] = list_ledata(le);
\t}
\tfor (le = list_head(&s_playl); le; le = le->next) {
\t\tif (np >= 2)
\t\t\treturn false;
\t\tplay[np++] = list_ledata(le);
\t}

\tif (ns != 2 || np != 2)
\t\treturn false;

\treturn
\t\tsame_audio_format(src[0]->prm.fmt, src[0]->prm.srate,
\t\t                 src[0]->prm.ch, src[0]->prm.ptime,
\t\t                 src[1]->prm.fmt, src[1]->prm.srate,
\t\t                 src[1]->prm.ch, src[1]->prm.ptime) &&
\t\tsame_audio_format(play[0]->prm.fmt, play[0]->prm.srate,
\t\t                 play[0]->prm.ch, play[0]->prm.ptime,
\t\t                 play[1]->prm.fmt, play[1]->prm.srate,
\t\t                 play[1]->prm.ch, play[1]->prm.ptime) &&
\t\tsame_audio_format(src[0]->prm.fmt, src[0]->prm.srate,
\t\t                 src[0]->prm.ch, src[0]->prm.ptime,
\t\t                 play[0]->prm.fmt, play[0]->prm.srate,
\t\t                 play[0]->prm.ch, play[0]->prm.ptime);
}

/* Feed the same microphone PCM into a single call's encoder FIFO. */
static int push_one_source(struct mdt_ausrc_st *st, const int16_t *pcm,
                           size_t nsamp)
{
\tstruct auframe af;
\tint err;

\tif (!st->prm.ch || nsamp % st->prm.ch)
\t\treturn EINVAL;

\tauframe_init(&af, AUFMT_S16LE, (void *)pcm, nsamp,
\t             st->prm.srate, st->prm.ch);
\taf.timestamp = tmr_jiffies_usec();
\terr = aubuf_write_auframe(st->ab, &af);
\tif (err)
\t\treturn err;

\twhile (aubuf_cur_size(st->ab) >= st->sampc * 2) {
\t\tsize_t before = aubuf_cur_size(st->ab);
\t\tauframe_init(&af, AUFMT_S16LE, st->frame, st->sampc,
\t\t             st->prm.srate, st->prm.ch);
\t\taubuf_read_auframe(st->ab, &af);
\t\tif (aubuf_cur_size(st->ab) >= before)
\t\t\tbreak;
\t\taf.timestamp = tmr_jiffies_usec();
\t\tst->rh(&af, st->arg);
\t}
\treturn 0;
}

/* Reuse each player's scratch buffer and split large requests into ptime
 * chunks. The app's realtime pull path therefore allocates no memory. */
static void play_one_to_buffer(struct mdt_auplay_st *st, int16_t *pcm,
                               size_t nsamp)
{
\tstruct auframe af;
\tsize_t offset = 0;
\twhile (offset < nsamp) {
\t\tsize_t chunk = nsamp - offset;
\t\tif (chunk > st->sampc)
\t\t\tchunk = st->sampc;
\t\tauframe_init(&af, AUFMT_S16LE, pcm + offset, chunk,
\t\t             st->prm.srate, st->prm.ch);
\t\taf.timestamp = tmr_jiffies_usec();
\t\tst->wh(&af, st->arg);
\t\toffset += chunk;
\t}
}

/* Average the two remote playback streams. This is overflow-safe even when
 * both decoded callers peak at full scale. */
static void mix_one_playback(struct mdt_auplay_st *st, int16_t *pcm,
                             size_t nsamp)
{
\tstruct auframe af;
\tsize_t offset = 0;
\twhile (offset < nsamp) {
\t\tsize_t chunk = nsamp - offset;
\t\tif (chunk > st->sampc)
\t\t\tchunk = st->sampc;
\t\tauframe_init(&af, AUFMT_S16LE, st->frame, chunk,
\t\t             st->prm.srate, st->prm.ch);
\t\taf.timestamp = tmr_jiffies_usec();
\t\tst->wh(&af, st->arg);
\t\tfor (size_t i = 0; i < chunk; ++i) {
\t\t\tint32_t mixed = (int32_t)pcm[offset + i] +
\t\t\t                (int32_t)st->frame[i];
\t\t\tpcm[offset + i] = (int16_t)(mixed / 2);
\t\t}
\t\toffset += chunk;
\t}
}""", "audio mixer helpers")

    replace_once(c,
"""static bool conference_format_valid_locked(void)
{
\tstruct mdt_ausrc_st *src[2] = {NULL, NULL};
\tstruct mdt_auplay_st *play[2] = {NULL, NULL};
\tstruct le *le;
\tunsigned ns = 0, np = 0;

\tfor (le = list_head(&s_srcl); le; le = le->next) {
\t\tif (ns >= 2)
\t\t\treturn false;
\t\tsrc[ns++] = list_ledata(le);
\t}
\tfor (le = list_head(&s_playl); le; le = le->next) {
\t\tif (np >= 2)
\t\t\treturn false;
\t\tplay[np++] = list_ledata(le);
\t}

\tif (ns != 2 || np != 2)
\t\treturn false;

\treturn
\t\tsame_audio_format(src[0]->prm.fmt, src[0]->prm.srate,
\t\t                 src[0]->prm.ch, src[0]->prm.ptime,
\t\t                 src[1]->prm.fmt, src[1]->prm.srate,
\t\t                 src[1]->prm.ch, src[1]->prm.ptime) &&
\t\tsame_audio_format(play[0]->prm.fmt, play[0]->prm.srate,
\t\t                 play[0]->prm.ch, play[0]->prm.ptime,
\t\t                 play[1]->prm.fmt, play[1]->prm.srate,
\t\t                 play[1]->prm.ch, play[1]->prm.ptime) &&
\t\tsame_audio_format(src[0]->prm.fmt, src[0]->prm.srate,
\t\t                 src[0]->prm.ch, src[0]->prm.ptime,
\t\t                 play[0]->prm.fmt, play[0]->prm.srate,
\t\t                 play[0]->prm.ch, play[0]->prm.ptime);
}""",
"""static struct mdt_auplay_st *play_for_owner(void *owner)
{
\tstruct le *le;
\tfor (le = list_head(&s_playl); le; le = le->next) {
\t\tstruct mdt_auplay_st *play = list_ledata(le);
\t\tif (mdt_aurecv_owner(play->arg) == owner)
\t\t\treturn play;
\t}
\treturn NULL;
}

/* Source A receives the decoded stream from the other party, B. */
static struct mdt_auplay_st *peer_play_for_source(const struct mdt_ausrc_st *src)
{
\tstruct le *le;
\tstruct mdt_auplay_st *found = NULL;
\tfor (le = list_head(&s_playl); le; le = le->next) {
\t\tstruct mdt_auplay_st *play = list_ledata(le);
\t\tvoid *owner = mdt_aurecv_owner(play->arg);
\t\tif (owner && owner != src->arg) {
\t\t\tif (found)
\t\t\t\treturn NULL;
\t\t\tfound = play;
\t\t}
\t}
\treturn found;
}

/* Called with s_lock held. Pair each transmit source with its own receive
 * stream by parent audio-object identity, never by list insertion order. */
static bool conference_format_valid_locked(void)
{
\tstruct mdt_ausrc_st *src[2] = {NULL, NULL};
\tstruct mdt_auplay_st *play[2] = {NULL, NULL};
\tstruct le *le;
\tunsigned ns = 0, np = 0;

\tfor (le = list_head(&s_srcl); le; le = le->next) {
\t\tif (ns >= 2)
\t\t\treturn false;
\t\tsrc[ns++] = list_ledata(le);
\t}
\tfor (le = list_head(&s_playl); le; le = le->next) {
\t\tif (np >= 2)
\t\t\treturn false;
\t\tplay[np++] = list_ledata(le);
\t}
\tif (ns != 2 || np != 2 || !src[0]->arg || !src[1]->arg ||
\t    src[0]->arg == src[1]->arg)
\t\treturn false;

\tplay[0] = play_for_owner(src[0]->arg);
\tplay[1] = play_for_owner(src[1]->arg);
\tif (!play[0] || !play[1] || play[0] == play[1] ||
\t    !play[0]->crossbuf || !play[1]->crossbuf ||
\t    peer_play_for_source(src[0]) != play[1] ||
\t    peer_play_for_source(src[1]) != play[0])
\t\treturn false;

\treturn
\t\tsame_audio_format(src[0]->prm.fmt, src[0]->prm.srate,
\t\t                 src[0]->prm.ch, src[0]->prm.ptime,
\t\t                 src[1]->prm.fmt, src[1]->prm.srate,
\t\t                 src[1]->prm.ch, src[1]->prm.ptime) &&
\t\tsame_audio_format(play[0]->prm.fmt, play[0]->prm.srate,
\t\t                 play[0]->prm.ch, play[0]->prm.ptime,
\t\t                 play[1]->prm.fmt, play[1]->prm.srate,
\t\t                 play[1]->prm.ch, play[1]->prm.ptime) &&
\t\tsame_audio_format(src[0]->prm.fmt, src[0]->prm.srate,
\t\t                 src[0]->prm.ch, src[0]->prm.ptime,
\t\t                 play[0]->prm.fmt, play[0]->prm.srate,
\t\t                 play[0]->prm.ch, play[0]->prm.ptime);
}""", "pair audio streams by call owner")

    replace_once(c,
"""static int push_one_source(struct mdt_ausrc_st *st, const int16_t *pcm,
                           size_t nsamp)
{
\tstruct auframe af;
\tint err;

\tif (!st->prm.ch || nsamp % st->prm.ch)
\t\treturn EINVAL;

\tauframe_init(&af, AUFMT_S16LE, (void *)pcm, nsamp,
\t             st->prm.srate, st->prm.ch);
\taf.timestamp = tmr_jiffies_usec();
\terr = aubuf_write_auframe(st->ab, &af);
\tif (err)
\t\treturn err;

\twhile (aubuf_cur_size(st->ab) >= st->sampc * 2) {
\t\tsize_t before = aubuf_cur_size(st->ab);
\t\tauframe_init(&af, AUFMT_S16LE, st->frame, st->sampc,
\t\t             st->prm.srate, st->prm.ch);
\t\taubuf_read_auframe(st->ab, &af);
\t\tif (aubuf_cur_size(st->ab) >= before)
\t\t\tbreak;
\t\taf.timestamp = tmr_jiffies_usec();
\t\tst->rh(&af, st->arg);
\t}
\treturn 0;
}""",
"""static int push_one_source(struct mdt_ausrc_st *st,
                           struct mdt_auplay_st *peer_play,
                           const int16_t *pcm, size_t nsamp)
{
\tstruct auframe af, peer_af;
\tint err;

\tif (!st->prm.ch || nsamp % st->prm.ch)
\t\treturn EINVAL;

\tauframe_init(&af, AUFMT_S16LE, (void *)pcm, nsamp,
\t             st->prm.srate, st->prm.ch);
\taf.timestamp = tmr_jiffies_usec();
\terr = aubuf_write_auframe(st->ab, &af);
\tif (err)
\t\treturn err;

\twhile (aubuf_cur_size(st->ab) >= st->sampc * 2) {
\t\tsize_t before = aubuf_cur_size(st->ab);
\t\tauframe_init(&af, AUFMT_S16LE, st->frame, st->sampc,
\t\t             st->prm.srate, st->prm.ch);
\t\taubuf_read_auframe(st->ab, &af);
\t\tif (aubuf_cur_size(st->ab) >= before)
\t\t\tbreak;

\t\tif (peer_play) {
\t\t\tif (!peer_play->crossbuf || peer_play->sampc != st->sampc ||
\t\t\t    peer_play->prm.srate != st->prm.srate ||
\t\t\t    peer_play->prm.ch != st->prm.ch)
\t\t\t\treturn EINVAL;
\t\t\tauframe_init(&peer_af, AUFMT_S16LE, peer_play->frame,
\t\t\t             st->sampc, st->prm.srate, st->prm.ch);
\t\t\tpeer_af.timestamp = tmr_jiffies_usec();
\t\t\taubuf_read_auframe(peer_play->crossbuf, &peer_af);

\t\t\t/* Each remote caller hears the local microphone plus the
\t\t\t * other remote caller. Averaging is overflow-safe. */
\t\t\tfor (size_t i = 0; i < st->sampc; ++i) {
\t\t\t\tint32_t mixed = (int32_t)st->frame[i] +
\t\t\t\t                (int32_t)peer_play->frame[i];
\t\t\t\tst->frame[i] = (int16_t)(mixed / 2);
\t\t\t}
\t\t}

\t\taf.timestamp = tmr_jiffies_usec();
\t\tst->rh(&af, st->arg);
\t}
\treturn 0;
}""", "cross-feed remote audio into other call")

    replace_once(c,
"""static void mix_one_playback(struct mdt_auplay_st *st, int16_t *pcm,
                             size_t nsamp)
{
\tstruct auframe af;
\tsize_t offset = 0;
\twhile (offset < nsamp) {
\t\tsize_t chunk = nsamp - offset;
\t\tif (chunk > st->sampc)
\t\t\tchunk = st->sampc;
\t\tauframe_init(&af, AUFMT_S16LE, st->frame, chunk,
\t\t             st->prm.srate, st->prm.ch);
\t\taf.timestamp = tmr_jiffies_usec();
\t\tst->wh(&af, st->arg);
\t\tfor (size_t i = 0; i < chunk; ++i) {
\t\t\tint32_t mixed = (int32_t)pcm[offset + i] +
\t\t\t                (int32_t)st->frame[i];
\t\t\tpcm[offset + i] = (int16_t)(mixed / 2);
\t\t}
\t\toffset += chunk;
\t}
}""",
"""static void mix_one_playback(struct mdt_auplay_st *st, int16_t *pcm,
                             size_t nsamp)
{
\tfor (size_t i = 0; i < nsamp; ++i) {
\t\tint32_t mixed = (int32_t)pcm[i] + (int32_t)st->frame[i];
\t\tpcm[i] = (int16_t)(mixed / 2);
\t}
}

/* Read each remote stream once, cache it for the opposite encoder, then
 * locally mix both streams for the user's speaker. */
static int conference_pull(struct mdt_auplay_st *play0,
                           struct mdt_auplay_st *play1,
                           int16_t *pcm, size_t nsamp)
{
\tstruct auframe af0, af1;
\tsize_t offset = 0;
\tint err;

\twhile (offset < nsamp) {
\t\tsize_t chunk = nsamp - offset;
\t\tif (chunk > play0->sampc) chunk = play0->sampc;
\t\tif (chunk > play1->sampc) chunk = play1->sampc;
\t\tif (!chunk)
\t\t\treturn EINVAL;

\t\tplay_one_to_buffer(play0, pcm + offset, chunk);
\t\tplay_one_to_buffer(play1, play1->frame, chunk);

\t\tauframe_init(&af0, AUFMT_S16LE, pcm + offset, chunk,
\t\t             play0->prm.srate, play0->prm.ch);
\t\taf0.timestamp = tmr_jiffies_usec();
\t\terr = aubuf_write_auframe(play0->crossbuf, &af0);
\t\tif (err) {
\t\t\taubuf_flush(play0->crossbuf);
\t\t\terr = aubuf_write_auframe(play0->crossbuf, &af0);
\t\t\tif (err) return err;
\t\t}

\t\tauframe_init(&af1, AUFMT_S16LE, play1->frame, chunk,
\t\t             play1->prm.srate, play1->prm.ch);
\t\taf1.timestamp = tmr_jiffies_usec();
\t\terr = aubuf_write_auframe(play1->crossbuf, &af1);
\t\tif (err) {
\t\t\taubuf_flush(play1->crossbuf);
\t\t\terr = aubuf_write_auframe(play1->crossbuf, &af1);
\t\t\tif (err) return err;
\t\t}

\t\tmix_one_playback(play1, pcm + offset, chunk);
\t\toffset += chunk;
\t}
\treturn 0;
}""", "mix and cross-feed received PCM")


    replace_once(c,
"""\tmtx_lock(&s_lock);
\tlist_unlink(&st->le);
\tmtx_unlock(&s_lock);

\tmem_deref(st->ab);""",
"""\tmtx_lock(&s_lock);
\tlist_unlink(&st->le);
\ts_conference = false;
\tmtx_unlock(&s_lock);

\tmem_deref(st->ab);""", "capture teardown")

    replace_once(c,
"""static void auplay_destructor(void *arg)
{
\tstruct mdt_auplay_st *st = arg;

\tmtx_lock(&s_lock);
\tlist_unlink(&st->le);
\tmtx_unlock(&s_lock);
}""",
"""static void auplay_destructor(void *arg)
{
\tstruct mdt_auplay_st *st = arg;

\tmtx_lock(&s_lock);
\tlist_unlink(&st->le);
\ts_conference = false;
\tmtx_unlock(&s_lock);

\tmem_deref(st->frame);
}""", "playback teardown")

    replace_once(c,
"""\tst->wh  = wh;
\tst->arg = arg;
\tst->prm = *prm;

\tmtx_lock(&s_lock);""",
"""\tst->wh    = wh;
\tst->arg   = arg;
\tst->prm   = *prm;
\tst->sampc = nsamp_for(prm->srate, prm->ch, prm->ptime);
\tst->frame = mem_zalloc(st->sampc * sizeof(int16_t), NULL);
\tif (!st->frame) {
\t\tmem_deref(st);
\t\treturn ENOMEM;
\t}

\tmtx_lock(&s_lock);""", "playback scratch frame")

    replace_once(c,
"""int medut_audio_external_push(const int16_t *pcm, size_t nsamp)
{
\tstruct auframe af;
\tint err;

\tif (!pcm || !nsamp)
\t\treturn EINVAL;
\tif (!re_atomic_rlx(&s_ready))
\t\treturn ENODEV;

\tmtx_lock(&s_lock);

\tstruct mdt_ausrc_st *st = cur_src();
\tif (!st) {
\t\t/* No call is capturing. Not an error the app can act on — it
\t\t * simply pushed between calls — so say so quietly. */
\t\tmtx_unlock(&s_lock);
\t\treturn ENODEV;
\t}

\tif (nsamp % st->prm.ch) {
\t\t/* A partial frame would silently shift every later sample into
\t\t * the wrong channel, which sounds like garbage rather than like
\t\t * a bug.  Say so instead. */
\t\tmtx_unlock(&s_lock);
\t\treturn EINVAL;
\t}

\tauframe_init(&af, AUFMT_S16LE, (void *)pcm, nsamp,
\t             st->prm.srate, st->prm.ch);
\taf.timestamp = tmr_jiffies_usec();

\terr = aubuf_write_auframe(st->ab, &af);
\tif (err) {
\t\tmtx_unlock(&s_lock);
\t\treturn err;
\t}

\t/* Hand the encoder whole frames only; it is written for a device that
\t * delivers a fixed ptime, and the app's buffer size is its own business. */
\twhile (aubuf_cur_size(st->ab) >= st->sampc * 2) {

\t\tsize_t before = aubuf_cur_size(st->ab);

\t\tauframe_init(&af, AUFMT_S16LE, st->frame, st->sampc,
\t\t             st->prm.srate, st->prm.ch);
\t\taubuf_read_auframe(st->ab, &af);

\t\t/* aubuf hands back silence without draining while it is still
\t\t * pre-filling.  Bail rather than spin: this runs on the app's
\t\t * realtime capture thread holding s_lock, so a spin here wedges
\t\t * the device teardown path with it. */
\t\tif (aubuf_cur_size(st->ab) >= before)
\t\t\tbreak;

\t\taf.timestamp = tmr_jiffies_usec();

\t\tst->rh(&af, st->arg);
\t}

\tmtx_unlock(&s_lock);
\treturn 0;
}""",
"""int medut_audio_external_set_conference(bool enable)
{
\tint err = 0;

\tif (!re_atomic_rlx(&s_ready))
\t\treturn enable ? ENODEV : 0;

\tmtx_lock(&s_lock);
\tif (enable) {
\t\tif (!conference_format_valid_locked())
\t\t\terr = EINVAL;
\t\telse
\t\t\ts_conference = true;
\t}
\telse {
\t\ts_conference = false;
\t}
\tmtx_unlock(&s_lock);
\treturn err;
}

int medut_audio_external_push(const int16_t *pcm, size_t nsamp)
{
\tint err = 0;

\tif (!pcm || !nsamp)
\t\treturn EINVAL;
\tif (!re_atomic_rlx(&s_ready))
\t\treturn ENODEV;

\tmtx_lock(&s_lock);

\tif (s_conference && !conference_format_valid_locked())
\t\ts_conference = false;

\tif (s_conference) {
\t\tstruct le *le;
\t\tunsigned count = 0;
\t\tfor (le = list_head(&s_srcl); le; le = le->next) {
\t\t\tstruct mdt_ausrc_st *st = list_ledata(le);
\t\t\t++count;
\t\t\terr = push_one_source(st, pcm, nsamp);
\t\t\tif (err)
\t\t\t\tbreak;
\t\t}
\t\tif (!err && count != 2)
\t\t\terr = ENODEV;
\t}
\telse {
\t\tstruct mdt_ausrc_st *st = cur_src();
\t\tif (!st)
\t\t\terr = ENODEV;
\t\telse
\t\t\terr = push_one_source(st, pcm, nsamp);
\t}

\tmtx_unlock(&s_lock);
\treturn err;
}""", "capture fan-out")

    replace_once(c,
"""int medut_audio_external_pull(int16_t *pcm, size_t nsamp)
{
\tstruct auframe af;

\tif (!pcm || !nsamp)
\t\treturn EINVAL;

\t/* Silence, not stale audio, whenever there is nothing to play: the app
\t * hands this straight to the speaker and must always get a full buffer
\t * back, call or no call. */
\tmemset(pcm, 0, nsamp * 2);

\tif (!re_atomic_rlx(&s_ready))
\t\treturn ENODEV;

\tmtx_lock(&s_lock);

\tstruct mdt_auplay_st *st = cur_play();
\tif (!st) {
\t\tmtx_unlock(&s_lock);
\t\treturn ENODEV;
\t}

\tif (nsamp % st->prm.ch) {
\t\tmtx_unlock(&s_lock);
\t\treturn EINVAL;
\t}

\tauframe_init(&af, AUFMT_S16LE, pcm, nsamp, st->prm.srate, st->prm.ch);
\tst->wh(&af, st->arg);

\tmtx_unlock(&s_lock);
\treturn 0;
}""",
"""int medut_audio_external_pull(int16_t *pcm, size_t nsamp)
{
\tif (!pcm || !nsamp)
\t\treturn EINVAL;

\t/* Always hand the platform a complete buffer, silence between calls. */
\tmemset(pcm, 0, nsamp * sizeof(int16_t));

\tif (!re_atomic_rlx(&s_ready))
\t\treturn ENODEV;

\tmtx_lock(&s_lock);

\tif (s_conference && !conference_format_valid_locked())
\t\ts_conference = false;

\tif (s_conference) {
\t\tstruct mdt_auplay_st *play[2] = {NULL, NULL};
\t\tstruct le *le;
\t\tunsigned count = 0;

\t\tfor (le = list_head(&s_playl); le; le = le->next) {
\t\t\tif (count >= 2) {
\t\t\t\tcount = 3;
\t\t\t\tbreak;
\t\t\t}
\t\t\tplay[count++] = list_ledata(le);
\t\t}

\t\tif (count != 2 || !play[0]->prm.ch || !play[1]->prm.ch ||
\t\t    nsamp % play[0]->prm.ch || nsamp % play[1]->prm.ch) {
\t\t\ts_conference = false;
\t\t\tmtx_unlock(&s_lock);
\t\t\treturn ENODEV;
\t\t}

\t\tplay_one_to_buffer(play[0], pcm, nsamp);
\t\tmix_one_playback(play[1], pcm, nsamp);
\t}
\telse {
\t\tstruct mdt_auplay_st *st = cur_play();
\t\tstruct auframe af;
\t\tif (!st) {
\t\t\tmtx_unlock(&s_lock);
\t\t\treturn ENODEV;
\t\t}
\t\tif (!st->prm.ch || nsamp % st->prm.ch) {
\t\t\tmtx_unlock(&s_lock);
\t\t\treturn EINVAL;
\t\t}
\t\tauframe_init(&af, AUFMT_S16LE, pcm, nsamp,
\t\t             st->prm.srate, st->prm.ch);
\t\tst->wh(&af, st->arg);
\t}

\tmtx_unlock(&s_lock);
\treturn 0;
}""", "playback mix")

    replace_once(c,
"""\tmtx_lock(&s_lock);
\tlist_clear(&s_srcl);
\tlist_clear(&s_playl);
\tmtx_unlock(&s_lock);""",
"""\tmtx_lock(&s_lock);
\ts_conference = false;
\tlist_clear(&s_srcl);
\tlist_clear(&s_playl);
\tmtx_unlock(&s_lock);""", "reset mixer on shutdown")

    header = SDK / "include/medut.h"
    replace_once(header,
"""MEDUT_EXPORT int medut_audio_use_external(bool enable);

/**
 * Give the stack captured microphone audio.""",
"""MEDUT_EXPORT int medut_audio_use_external(bool enable);

/**
 * Enable a device-local two-call conference on an app-owned audio device.
 * The same microphone PCM is sent to both SIP legs and both decoded streams
 * are mixed locally for playback; no PBX conference room is involved.
 * Requires exactly two compatible full-duplex S16LE media streams.
 * Returns 0, ENODEV if the app-owned device is inactive, or EINVAL until
 * both calls have opened matching audio formats. Passing false disables it.
 */
MEDUT_EXPORT int medut_audio_external_set_conference(bool enable);

/**
 * Give the stack captured microphone audio.""", "public SDK header")

    jni = SDK / "platform/android/audio_external_jni.c"
    replace_once(jni,
"""JNIEXPORT void JNI_FN(nativeSetVoicePath)(JNIEnv *env, jclass cls,
                                          jboolean active)
{
\t(void)env; (void)cls;
\tmedut_audio_external_set_voice_path(active == JNI_TRUE);
}""",
"""JNIEXPORT void JNI_FN(nativeSetVoicePath)(JNIEnv *env, jclass cls,
                                          jboolean active)
{
\t(void)env; (void)cls;
\tmedut_audio_external_set_voice_path(active == JNI_TRUE);
}

JNIEXPORT jint JNI_FN(nativeSetConference)(JNIEnv *env, jclass cls,
                                           jboolean enable)
{
\t(void)env; (void)cls;
\treturn medut_audio_external_set_conference(enable == JNI_TRUE);
}""", "Android JNI API")

    ext = SDK / "bindings/kotlin/medut/src/main/kotlin/dev/medut/android/ExternalAudio.kt"
    replace_once(ext,
"""    private external fun nativeSetVoicePath(active: Boolean)

    /**
     * Tell the SDK whether capture runs through the platform's voice path""",
"""    private external fun nativeSetVoicePath(active: Boolean)
    private external fun nativeSetConference(enable: Boolean): Int

    /** Enable/disable local mixing of two compatible SIP call legs. */
    fun setConference(enabled: Boolean): Int = nativeSetConference(enabled)

    /**
     * Tell the SDK whether capture runs through the platform's voice path""", "Kotlin JNI bridge")

    audio = SDK / "bindings/kotlin/medut/src/main/kotlin/dev/medut/MedutAudio.kt"
    replace_once(audio,
"""    fun setExternalVoicePath(active: Boolean) = Native.audioExternalSetVoicePath(active)
}""",
"""    fun setExternalVoicePath(active: Boolean) = Native.audioExternalSetVoicePath(active)

    /** Enable the native two-call local PCM mix after both calls have media. */
    fun setConferenceMixing(enabled: Boolean) =
        gate.read(null, "medut_audio_external_set_conference") {
            check(ExternalAudio.setConference(enabled), "medut_audio_external_set_conference")
        }
}""", "Kotlin public audio API")


def patch_android_app() -> None:
    engine = APP / "android/app/src/main/kotlin/com/medut/generic/phone/engine/PhoneEngine.kt"
    replace_once(engine,
"""    var focused: ActiveCall? = null
        private set
    val presence = HashMap<String, String>()""",
"""    var focused: ActiveCall? = null
        private set
    private var appOwnedAudioReady = false
    private var localConference = false
    private var conferencePending = false
    val presence = HashMap<String, String>()""", "Android mixer state")

    replace_once(engine,
"""            )
            sdkUp = true
        } catch (t: Throwable) {""",
"""            )
            sdkUp = true
            appOwnedAudioReady = runCatching {
                MedutAndroid.useAppOwnedAudio(true)
                true
            }.onFailure { Log.e(TAG, "App-owned audio unavailable; local merge disabled", it) }
                .getOrDefault(false)
        } catch (t: Throwable) {""", "start shared Android audio")

    replace_once(engine,
"""    private fun setMute(ac: ActiveCall, on: Boolean) {
        runCatching { ac.call.setMuted(on) }
        ac.muted = on
        push()
    }

    private fun hold(ac: ActiveCall) {
        if (ac.phase != Phase.ACTIVE) return""",
"""    private fun setMute(ac: ActiveCall, on: Boolean) {
        val targets = if (localConference) calls.toList() else listOf(ac)
        targets.forEach {
            runCatching { it.call.setMuted(on) }
            it.muted = on
        }
        push()
    }

    private fun hold(ac: ActiveCall) {
        if (localConference || conferencePending) unmergeCalls()
        if (ac.phase != Phase.ACTIVE) return""", "Android mute and hold")

    replace_once(engine,
"""    private fun resume(ac: ActiveCall) {
        for (other in calls.toList()) if (other !== ac && other.phase == Phase.ACTIVE) hold(other)""",
"""    private fun resume(ac: ActiveCall) {
        if (localConference || conferencePending) unmergeCalls()
        for (other in calls.toList()) if (other !== ac && other.phase == Phase.ACTIVE) hold(other)""", "Android resume")

    replace_once(engine,
"""    private fun swap() {
        calls.firstOrNull { it !== focused && it.phase != Phase.INCOMING }?.let(::resume)
    }

    private fun toggleRecord(ac: ActiveCall) {""",
"""    private fun swap() {
        calls.firstOrNull { it !== focused && it.phase != Phase.INCOMING }?.let(::resume)
    }

    private fun mergeCalls() {
        if (localConference || conferencePending) return
        if (!appOwnedAudioReady) {
            notice("Local audio mixer is unavailable on this device.")
            return
        }
        val pair = calls.toList()
        if (pair.size != 2 || pair.any {
                it.phase !in listOf(Phase.ACTIVE, Phase.HELD) ||
                    it.transferOf != null || it.transferring
            }) {
            notice("Both calls must be connected before merging.")
            return
        }

        conferencePending = true
        val heldBefore = pair.filter { it.call.state == dev.medut.CallState.HELD }
        for (ac in heldBefore) {
            runCatching { ac.call.resume() }.onFailure {
                rollbackConference(heldBefore, "Could not resume both calls: ${it.message}")
                return
            }
        }
        waitForConference(pair, heldBefore, 0)
    }

    private fun waitForConference(pair: List<ActiveCall>, heldBefore: List<ActiveCall>, attempt: Int) {
        if (!conferencePending) return
        if (pair.any { !calls.contains(it) || it.call.isEnded }) {
            conferencePending = false
            push()
            return
        }
        if (pair.any { it.call.state != dev.medut.CallState.ESTABLISHED }) {
            if (attempt >= 30) {
                rollbackConference(heldBefore, "Both calls did not resume in time.")
            } else {
                main.postDelayed({ waitForConference(pair, heldBefore, attempt + 1) }, 200)
            }
            return
        }

        val enabled = runCatching { Medut.audio.setConferenceMixing(true) }
        if (enabled.isSuccess) {
            conferencePending = false
            localConference = true
            pair.forEach { it.phase = Phase.ACTIVE }
            focused = focused?.takeIf { pair.contains(it) } ?: pair.first()
            push()
            pushState()
        } else if (attempt < 15) {
            // Device streams can open a few milliseconds after SIP ESTABLISHED.
            main.postDelayed({ waitForConference(pair, heldBefore, attempt + 1) }, 200)
        } else {
            rollbackConference(heldBefore, "Merge failed: both calls need compatible audio formats.")
        }
    }

    private fun rollbackConference(heldBefore: List<ActiveCall>, message: String) {
        conferencePending = false
        heldBefore.forEach {
            if (it.call.state == dev.medut.CallState.ESTABLISHED) {
                runCatching { it.call.hold() }
                it.phase = Phase.HELD
            }
        }
        notice(message)
        push()
        pushState()
    }

    private fun clearLocalConference() {
        conferencePending = false
        if (appOwnedAudioReady) runCatching { Medut.audio.setConferenceMixing(false) }
        localConference = false
    }

    private fun unmergeCalls() {
        if (!localConference && !conferencePending) return
        val pair = calls.toList()
        clearLocalConference()
        val other = pair.firstOrNull { it !== focused && it.phase == Phase.ACTIVE }
        if (other != null) hold(other)
        push()
        pushState()
    }

    private fun toggleRecord(ac: ActiveCall) {""", "Android local merge engine")

    replace_once(engine,
"""            "swap" -> swap()
            "answerWaiting" -> calls.firstOrNull { it.phase == Phase.INCOMING }?.let(::answer)""",
"""            "swap" -> swap()
            "merge" -> mergeCalls()
            "unmerge" -> unmergeCalls()
            "answerWaiting" -> calls.firstOrNull { it.phase == Phase.INCOMING }?.let(::answer)""", "Android merge actions")

    replace_once(engine,
"""    fun hangup(ac: ActiveCall) {
        ac.endedLocally = true""",
"""    fun hangup(ac: ActiveCall) {
        if (localConference || conferencePending) clearLocalConference()
        ac.endedLocally = true""", "Android call end clears mix")

    replace_once(engine,
"""    private fun finish(ac: ActiveCall, failed: Boolean, reason: String?, state: dev.medut.CallState) {
        ac.info = runCatching { ac.call.info() }.getOrNull() ?: ac.info // last chance for the final SIP status
        calls.remove(ac)""",
"""    private fun finish(ac: ActiveCall, failed: Boolean, reason: String?, state: dev.medut.CallState) {
        ac.info = runCatching { ac.call.info() }.getOrNull() ?: ac.info // last chance for the final SIP status
        calls.remove(ac)
        if (localConference || conferencePending) clearLocalConference()""", "Android peer hangup clears mix")

    replace_once(engine,
"""                f.transferOf === it -> mapOf("name" to it.title,
                    "text" to "${it.title} · ${l.label("onHold", "On hold")}",
                    "label" to l.label("complete", "Complete"), "action" to "completeTransfer")
                else -> mapOf("name" to it.title,
                    "text" to "${it.title} · ${l.label("onHold", "On hold")}",
                    "label" to l.label("swap", "Swap"), "action" to "swap")""",
"""                f.transferOf === it -> mapOf("name" to it.title,
                    "text" to "${it.title} · ${l.label("onHold", "On hold")}",
                    "label" to l.label("complete", "Complete"), "action" to "completeTransfer")
                localConference -> mapOf("name" to it.title,
                    "text" to "${l.label("merge", "Merged")} · ${it.title}",
                    "label" to l.label("unmerge", "Unmerge"), "action" to "unmerge")
                conferencePending -> mapOf("name" to it.title,
                    "text" to "${it.title} · ${l.label("connecting", "Connecting…")}",
                    "label" to l.label("merging", "Merging…"), "action" to "merge")
                pairCanMerge(f, it) -> mapOf("name" to it.title,
                    "text" to "${it.title} · ${l.label("readyToMerge", "Ready to merge")}",
                    "label" to l.label("merge", "Merge"), "action" to "merge")
                else -> mapOf("name" to it.title,
                    "text" to "${it.title} · ${l.label("onHold", "On hold")}",
                    "label" to l.label("swap", "Swap"), "action" to "swap")""", "Android merge snapshot")

    replace_once(engine,
"""    private fun setProximity(on: Boolean) {""",
"""    private fun pairCanMerge(a: ActiveCall, b: ActiveCall): Boolean =
        calls.size == 2 &&
            a.phase in listOf(Phase.ACTIVE, Phase.HELD) &&
            b.phase in listOf(Phase.ACTIVE, Phase.HELD) &&
            a.transferOf == null && b.transferOf == null &&
            !a.transferring && !b.transferring

    private fun setProximity(on: Boolean) {""", "Android merge eligibility")


def patch_desktop_app() -> None:
    engine = APP / "lib/desktop/engine.dart"
    replace_once(engine,
"""  final calls = <ActiveCall>[];
  ActiveCall? focused;
  final presence = <String, String>{};""",
"""  final calls = <ActiveCall>[];
  ActiveCall? focused;
  bool localConference = false;
  bool _conferencePending = false;
  final presence = <String, String>{};""", "Desktop mixer state")

    replace_once(engine,
"""  Future<void> _finish(ActiveCall ac, bool failed, String? reason, sdk.CallState state) async {
    if (!calls.remove(ac)) return;
    ac.autoAnswer?.cancel();""",
"""  Future<void> _finish(ActiveCall ac, bool failed, String? reason, sdk.CallState state) async {
    if (!calls.remove(ac)) return;
    if (localConference || _conferencePending) {
      localConference = false;
      _conferencePending = false;
    }
    ac.autoAnswer?.cancel();""", "Desktop call finish")

    replace_once(engine,
"""      case 'swap':
        final other = calls.where((c) => c != focused && c.phase != Phase.incoming).firstOrNull;
        if (other != null) await _resume(other);
      case 'answerWaiting':""",
"""      case 'swap':
        final other = calls.where((c) => c != focused && c.phase != Phase.incoming).firstOrNull;
        if (other != null) await _resume(other);
      case 'merge':
        await _mergeCalls();
      case 'unmerge':
        await _unmergeCalls();
      case 'answerWaiting':""", "Desktop action dispatch")

    replace_once(engine,
"""  Future<void> hangup(ActiveCall ac) async {
    ac.endedLocally = true;""",
"""  Future<void> hangup(ActiveCall ac) async {
    if (localConference || _conferencePending) {
      localConference = false;
      _conferencePending = false;
    }
    ac.endedLocally = true;""", "Desktop local hangup")

    replace_once(engine,
"""  Future<void> _setMute(ActiveCall ac, bool on) async {
    await _quiet(() => ac.call.mute(on: on));
    ac.muted = on;
    _push();
  }

  Future<void> _hold(ActiveCall ac) async {
    if (ac.phase != Phase.active) return;""",
"""  Future<void> _setMute(ActiveCall ac, bool on) async {
    final targets = localConference ? calls.toList() : <ActiveCall>[ac];
    for (final target in targets) {
      await _quiet(() => target.call.mute(on: on));
      target.muted = on;
    }
    _push();
  }

  Future<void> _hold(ActiveCall ac) async {
    if (localConference || _conferencePending) await _unmergeCalls();
    if (ac.phase != Phase.active) return;""", "Desktop mute and hold")

    replace_once(engine,
"""  Future<void> _resume(ActiveCall ac) async {
    for (final other in calls.toList()) {""",
"""  Future<void> _resume(ActiveCall ac) async {
    if (localConference || _conferencePending) await _unmergeCalls();
    for (final other in calls.toList()) {""", "Desktop resume")

    replace_once(engine,
"""  Future<void> _toggleRecord(ActiveCall ac) async {""",
"""  Future<void> _mergeCalls() async {
    if (!Platform.isWindows) {
      _notice('Local 3-way merge is supported on Windows and Android only.');
      return;
    }
    if (localConference || _conferencePending) return;
    final pair = calls.toList();
    if (pair.length != 2 || pair.any((c) =>
        (c.phase != Phase.active && c.phase != Phase.held) ||
        c.transferOf != null || c.transferring)) {
      _notice('Both calls must be connected before merging.');
      return;
    }

    _conferencePending = true;
    final heldBefore = pair.where((c) => c.phase == Phase.held).toList();
    try {
      for (final c in heldBefore) {
        await _quiet(() => c.call.resume());
      }
      var ready = false;
      for (var attempt = 0; attempt < 30 && calls.length == 2; attempt++) {
        if (pair.every((c) => calls.contains(c) && c.phase == Phase.active)) {
          ready = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      if (!ready) {
        for (final c in heldBefore) {
          if (calls.contains(c) && c.phase == Phase.active) await _hold(c);
        }
        _conferencePending = false;
        _notice('Both calls did not resume in time. Merge was cancelled.');
        _push();
        return;
      }
      // Windows WASAPI uses shared-mode capture/render clients: each SIP leg
      // receives the same local microphone and Windows mixes both playbacks.
      localConference = true;
      _conferencePending = false;
      _push();
      pushState();
    } catch (e) {
      for (final c in heldBefore) {
        if (calls.contains(c) && c.phase == Phase.active) await _hold(c);
      }
      _conferencePending = false;
      _notice('Merge failed: $e');
      _push();
    }
  }

  Future<void> _unmergeCalls() async {
    if (!localConference && !_conferencePending) return;
    localConference = false;
    _conferencePending = false;
    final other = calls.where((c) => c != focused && c.phase == Phase.active).firstOrNull;
    if (other != null) await _hold(other);
    _push();
    pushState();
  }

  Future<void> _toggleRecord(ActiveCall ac) async {""", "Desktop local merge methods")

    replace_once(engine,
"""            : f.transferOf == other
                ? {
                    'name': other.title,
                    'text': '${other.title} · ${l.label('onHold', 'On hold')}',
                    'label': l.label('complete', 'Complete'),
                    'action': 'completeTransfer',
                  }
                : {
                    'name': other.title,
                    'text': '${other.title} · ${l.label('onHold', 'On hold')}',
                    'label': l.label('swap', 'Swap'),
                    'action': 'swap',
                  };""",
"""            : f.transferOf == other
                ? {
                    'name': other.title,
                    'text': '${other.title} · ${l.label('onHold', 'On hold')}',
                    'label': l.label('complete', 'Complete'),
                    'action': 'completeTransfer',
                  }
                : localConference
                    ? {
                        'name': other.title,
                        'text': '${l.label('merge', 'Merged')} · ${other.title}',
                        'label': l.label('unmerge', 'Unmerge'),
                        'action': 'unmerge',
                      }
                    : _conferencePending
                        ? {
                            'name': other.title,
                            'text': '${other.title} · ${l.label('connecting', 'Connecting…')}',
                            'label': l.label('merging', 'Merging…'),
                            'action': 'merge',
                          }
                        : (f.phase == Phase.active || f.phase == Phase.held) &&
                                (other.phase == Phase.active || other.phase == Phase.held)
                            ? {
                                'name': other.title,
                                'text': '${other.title} · ${l.label('readyToMerge', 'Ready to merge')}',
                                'label': l.label('merge', 'Merge'),
                                'action': 'merge',
                              }
                            : {
                                'name': other.title,
                                'text': '${other.title} · ${l.label('onHold', 'On hold')}',
                                'label': l.label('swap', 'Swap'),
                                'action': 'swap',
                              };""", "Desktop merge snapshot")

    sip = APP / "lib/sip/sip_service.dart"
    replace_once(sip,
"""    'speaker', 'earpiece', 'bluetooth', 'headset', 'hold', 'resume', 'addCall', 'transfer', 'record',
    'stopRecord', 'hide', 'onHold', 'swap', 'callDetails', 'audioOutput', 'cancel', 'complete',""",
"""    'speaker', 'earpiece', 'bluetooth', 'headset', 'hold', 'resume', 'addCall', 'transfer', 'record',
    'stopRecord', 'hide', 'onHold', 'swap', 'merge', 'unmerge', 'merging', 'readyToMerge',
    'callDetails', 'audioOutput', 'cancel', 'complete',""", "merge labels")


def patch_pubspec() -> None:
    replace_once(APP / "pubspec.yaml",
"""  medut:
    git:
      url: https://github.com/Ibrahimgamal99/Medut-SDK.git
      path: bindings/flutter
      ref: b6354b138a56483611723132922edfef8715219b""",
"""  medut:
    path: ../../sdk/Medut-SDK/bindings/flutter""", "local patched SDK dependency")


def main() -> None:
    for path in (
        SDK / "src/audio/external.c",
        SDK / "include/medut.h",
        APP / "android/app/src/main/kotlin/com/medut/generic/phone/engine/PhoneEngine.kt",
        APP / "lib/desktop/engine.dart",
    ):
        if not path.exists():
            raise SystemExit(f"Required submodule file missing: {path}")
    patch_sdk()
    patch_android_app()
    patch_desktop_app()
    patch_pubspec()
    print("Shadow-SIP local 3-way conference patch applied.")


if __name__ == "__main__":
    main()
