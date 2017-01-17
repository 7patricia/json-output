#include "postgres.h"
#include "replication/logical.h"
#include "utils/builtins.h"
#include "utils/lsyscache.h"
#include "utils/json.h"

PG_MODULE_MAGIC;

void _PG_output_plugin_init(OutputPluginCallbacks *cb);

static void json_decode_startup(LogicalDecodingContext *ctx, OutputPluginOptions *opt, bool is_init);
static void json_decode_shutdown(LogicalDecodingContext *ctx);
static void json_decode_begin_txn(LogicalDecodingContext *ctx, ReorderBufferTXN *txn);
static void json_decode_commit_txn(LogicalDecodingContext *ctx, ReorderBufferTXN *txn, XLogRecPtr commit_lsn);
static void json_decode_change(LogicalDecodingContext *ctx, ReorderBufferTXN *txn, Relation rel, ReorderBufferChange *change);

void
_PG_output_plugin_init(OutputPluginCallbacks *cb)
{
	AssertVariableIsOfType(&_PG_output_plugin_init, LogicalOutputPluginInit);

	cb->startup_cb = json_decode_startup;
	cb->begin_cb = json_decode_begin_txn;
	cb->change_cb = json_decode_change;
	cb->commit_cb = json_decode_commit_txn;
	cb->shutdown_cb = json_decode_shutdown;
}

static void
json_decode_startup(LogicalDecodingContext *ctx, OutputPluginOptions *opt, bool is_init)
{
	opt->output_type = OUTPUT_PLUGIN_TEXTUAL_OUTPUT;
}

static void
json_decode_shutdown(LogicalDecodingContext *ctx)
{
}

static void
json_decode_begin_txn(LogicalDecodingContext *ctx, ReorderBufferTXN *txn)
{
}

static void
json_decode_commit_txn(LogicalDecodingContext *ctx, ReorderBufferTXN *txn, XLogRecPtr commit_lsn)
{
}

static HeapTuple
assign_tuple(HeapTuple dst, HeapTuple src, TupleDesc descr)
{
	static Datum values[MaxHeapAttributeNumber];
	static bool isnull[MaxHeapAttributeNumber];
	static bool replace[MaxHeapAttributeNumber];
	Oid typoutput;
	bool typisvarlena;
	struct varlena *value;
	int i;

	if (!dst && src)
		return src;

	heap_deform_tuple(dst, descr, values, isnull);

	for (i = 0; i < descr->natts; i++)
	{
		if (isnull[i])
			continue;

		value = (struct varlena *) DatumGetPointer(values[i]);

		getTypeOutputInfo(descr->attrs[i]->atttypid, &typoutput, &typisvarlena);

		isnull[i] = replace[i] = typisvarlena && VARATT_IS_EXTERNAL_ONDISK(value);
	}

	if (src)
		heap_deform_tuple(src, descr, values, isnull);

	return heap_modify_tuple(dst, descr, values, isnull, replace);
}

static void
json_decode_output_tuple(LogicalDecodingContext *ctx, const char *key, HeapTuple tuple, TupleDesc descr)
{
	if (tuple)
	{
		Datum row = heap_copy_tuple_as_datum(tuple, descr);
		Datum json = DirectFunctionCall1(row_to_json, row);
		char *out = text_to_cstring((text *) DatumGetPointer(json));
		appendStringInfo(ctx->out, ",\"%s\":%s", key, out);
	}
}

static void
json_decode_change(LogicalDecodingContext *ctx, ReorderBufferTXN *txn, Relation relation, ReorderBufferChange *change)
{
	Form_pg_class form;
	TupleDesc descr;
	HeapTuple newtuple = change->data.tp.newtuple ? &change->data.tp.newtuple->tuple : NULL;
	HeapTuple oldtuple = change->data.tp.oldtuple ? &change->data.tp.oldtuple->tuple : NULL;

	form = RelationGetForm(relation);
	descr = RelationGetDescr(relation);

	OutputPluginPrepareWrite(ctx, true);

	appendStringInfoString(ctx->out, "{\"schema\":");
	escape_json(ctx->out, get_namespace_name(get_rel_namespace(RelationGetRelid(relation))));

	appendStringInfoString(ctx->out, ",\"table\":");
	escape_json(ctx->out, NameStr(form->relname));

	switch (change->action)
	{
		case REORDER_BUFFER_CHANGE_INSERT:
			appendStringInfo(ctx->out, ",\"action\":\"insert\"");
			json_decode_output_tuple(ctx, "new", newtuple, descr);
			break;
		case REORDER_BUFFER_CHANGE_UPDATE:
			appendStringInfo(ctx->out, ",\"action\":\"update\"");
			json_decode_output_tuple(ctx, "new", assign_tuple(newtuple, oldtuple, descr), descr);
			json_decode_output_tuple(ctx, "old", oldtuple, descr);
			break;
		case REORDER_BUFFER_CHANGE_DELETE:
			appendStringInfo(ctx->out, ",\"action\":\"delete\"");
			json_decode_output_tuple(ctx, "old", oldtuple, descr);
			break;
		default:
			Assert(false);
	}

	appendStringInfoChar(ctx->out, '}');

	OutputPluginWrite(ctx, true);
}
