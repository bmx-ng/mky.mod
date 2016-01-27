/*

Copyright (c) 2015 Bruce Henderson

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgement in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.

*/
#include "brl.mod/blitz.mod/blitz.h"
#ifdef BMX_NG
#include "brl.mod/blitz.mod/tree/tree.h"
#else
#include "tree/tree.h"
#endif

#define generic_compare(x, y) (((x) > (y)) - ((x) < (y)))

/* +++++++++++++++++++++++++++++++++++++++++++++++++++++ */

struct stringfloatmap_node {
	struct avl_root link;
	BBString * key;
	float value;
};

static int compare_stringfloatmap_nodes(const void *x, const void *y) {
        struct stringfloatmap_node * node_x = (struct stringfloatmap_node *)x;
        struct stringfloatmap_node * node_y = (struct stringfloatmap_node *)y;

        return bbStringCompare(node_x->key, node_y->key);
}

void bmx_map_stringfloatmap_clear(struct avl_root ** root) {
	struct stringfloatmap_node *node;
	struct stringfloatmap_node *tmp;
	avl_for_each_entry_safe(node, tmp, *root, link) {
		BBRELEASE(node->key);
		avl_del(&node->link, root);
		free(node);
	}
}

int bmx_map_stringfloatmap_isempty(struct avl_root ** root) {
	return *root == 0;
}

void bmx_map_stringfloatmap_insert( BBString * key, float value, struct avl_root ** root) {
	struct stringfloatmap_node * node = (struct stringfloatmap_node *)malloc(sizeof(struct stringfloatmap_node));
	node->key = key;
	BBRETAIN(key);
	node->value = value;
	
	struct stringfloatmap_node * old_node = (struct stringfloatmap_node *)avl_map(&node->link, compare_stringfloatmap_nodes, root);

	if (&node->link != &old_node->link) {
		BBRELEASE(old_node->key);
		// key already exists. Store the value in this node.
		old_node->value = value;
		// delete the new node, since we don't need it
		free(node);
	}
}

int bmx_map_stringfloatmap_contains(BBString * key, struct avl_root ** root) {
	struct stringfloatmap_node node;
	node.key = key;
	
	struct stringfloatmap_node * found = (struct stringfloatmap_node *)tree_search(&node, compare_stringfloatmap_nodes, *root);
	if (found) {
		return 1;
	} else {
		return 0;
	}
}

float bmx_map_stringfloatmap_valueforkey(BBString * key, struct avl_root ** root) {
	struct stringfloatmap_node node;
	node.key = key;
	
	struct stringfloatmap_node * found = (struct stringfloatmap_node *)tree_search(&node, compare_stringfloatmap_nodes, *root);
	
	if (found) {
		return found->value;
	}
	
	return 0.0f;
}

int bmx_map_stringfloatmap_remove(BBString * key, struct avl_root ** root) {
	struct stringfloatmap_node node;
	node.key = key;
	
	struct stringfloatmap_node * found = (struct stringfloatmap_node *)tree_search(&node, compare_stringfloatmap_nodes, *root);
	
	if (found) {
		BBRELEASE(found->key);
		avl_del(&found->link, root);
		free(found);
		return 1;
	} else {
		return 0;
	}
}

struct stringfloatmap_node * bmx_map_stringfloatmap_nextnode(struct stringfloatmap_node * node) {
	return tree_successor(node);
}

struct stringfloatmap_node * bmx_map_stringfloatmap_firstnode(struct avl_root * root) {
	return tree_min(root);
}

BBString * bmx_map_stringfloatmap_key(struct stringfloatmap_node * node) {
	return node->key;
}

float bmx_map_stringfloatmap_value(struct stringfloatmap_node * node) {
	return node->value;
}

int bmx_map_stringfloatmap_hasnext(struct stringfloatmap_node * node, struct avl_root * root) {
	if (!root) {
		return 0;
	}
	
	if (!node) {
		return 1;
	}
	
	return (tree_successor(node) != 0) ? 1 : 0;
}

void bmx_map_stringfloatmap_copy(struct avl_root ** dst_root, struct avl_root * src_root) {
	struct stringfloatmap_node *src_node;
	struct stringfloatmap_node *tmp;
	avl_for_each_entry_safe(src_node, tmp, src_root, link) {
		bmx_map_stringfloatmap_insert(src_node->key, src_node->value, dst_root);
	}
}

/* +++++++++++++++++++++++++++++++++++++++++++++++++++++ */
