/*
 * Copyright (C) 1999, 2000  Internet Software Consortium.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND INTERNET SOFTWARE CONSORTIUM
 * DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL
 * INTERNET SOFTWARE CONSORTIUM BE LIABLE FOR ANY SPECIAL, DIRECT,
 * INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING
 * FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 * NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION
 * WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/* $Id: server.h,v 1.48 2000/12/12 21:33:11 bwelling Exp $ */

#ifndef NAMED_SERVER_H
#define NAMED_SERVER_H 1

#include <isc/log.h>
#include <isc/sockaddr.h>
#include <isc/types.h>
#include <isc/quota.h>

#include <dns/types.h>
#include <dns/acl.h>

#define NS_EVENTCLASS		ISC_EVENTCLASS(0x4E43)
#define NS_EVENT_RELOAD		(NS_EVENTCLASS + 0)
#define NS_EVENT_CLIENTCONTROL	(NS_EVENTCLASS + 1)

/*
 * Name server state.  Better here than in lots of separate global variables.
 */
struct ns_server {
	isc_uint32_t		magic;
	isc_mem_t *		mctx;

	isc_task_t *		task;

	/* Common rwlock for the server's configurable data. */
	isc_rwlock_t		conflock;

	/* Configurable data. */
	isc_quota_t		xfroutquota;
	isc_quota_t		tcpquota;
	isc_quota_t		recursionquota;
	dns_acl_t		*blackholeacl;

	/* Not really configurable, but covered by conflock. */
	dns_aclenv_t		aclenv;

	/* Server data structures. */
	dns_loadmgr_t *		loadmgr;
	dns_zonemgr_t *		zonemgr;
	dns_viewlist_t		viewlist;
	ns_interfacemgr_t *	interfacemgr;
	dns_db_t *		in_roothints;
	dns_tkeyctx_t *		tkeyctx;
	isc_timer_t *		interface_timer;
	isc_timer_t *		heartbeat_timer;

	isc_mutex_t		reload_event_lock;
	isc_event_t *		reload_event;

	isc_boolean_t		flushonshutdown;
	isc_boolean_t		log_queries;	/* For BIND 8 compatibility */

	char *			statsfile;	/* Statistics file name */
	isc_uint64_t *		querystats;	/* Query statistics counters */

	char *			dumpfile;	/* Dump file name */
};

#define NS_SERVER_MAGIC			0x53564552	/* SVER */
#define NS_SERVER_VALID(s)		((s) != NULL && \
					 (s)->magic == NS_SERVER_MAGIC)

void
ns_server_create(isc_mem_t *mctx, ns_server_t **serverp);
/*
 * Create a server object with default settings.
 * This function either succeeds or causes the program to exit
 * with a fatal error.
 */

void
ns_server_destroy(ns_server_t **serverp);
/*
 * Destroy a server object, freeing its memory.
 */

void
ns_server_reloadwanted(ns_server_t *server);
/*
 * Inform a server that a reload is wanted.  This function
 * may be called asynchronously, from outside the server's task.
 * If a reload is already scheduled or in progress, the call
 * is ignored.
 */

void
ns_server_flushonshutdown(ns_server_t *server, isc_boolean_t flush);
/*
 * Inform the server that the zones should be flushed to disk on shutdown.
 */

isc_result_t
ns_server_reloadcommand(ns_server_t *server, char *args);
/*
 * Act on a "reload" command from the command channel.
 */

isc_result_t
ns_server_refreshcommand(ns_server_t *server, char *args);
/*
 * Act on a "refresh" command from the command channel.
 */

isc_result_t
ns_server_togglequerylog(ns_server_t *server);
/*
 * Toggle logging of queries, as in BIND 8.
 */

/*
 * Dump the current statistics to the statistics file.
 */
isc_result_t
ns_server_dumpstats(ns_server_t *server);

/*
 * Dump the current cache to the dump file.
 */
isc_result_t
ns_server_dumpdb(ns_server_t *server);

#endif /* NAMED_SERVER_H */
