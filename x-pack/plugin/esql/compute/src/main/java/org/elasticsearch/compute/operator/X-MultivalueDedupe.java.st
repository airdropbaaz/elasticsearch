/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License
 * 2.0; you may not use this file except in compliance with the Elastic License
 * 2.0.
 */

package org.elasticsearch.compute.operator;

import org.apache.lucene.util.ArrayUtil;
$if(BytesRef)$
import org.apache.lucene.util.BytesRef;
import org.elasticsearch.common.util.BytesRefHash;
$else$
import org.elasticsearch.common.util.LongHash;
$endif$
import org.elasticsearch.compute.aggregation.GroupingAggregatorFunction;
import org.elasticsearch.compute.aggregation.blockhash.BlockHash;
import org.elasticsearch.compute.data.Block;
import org.elasticsearch.compute.data.BlockFactory;
$if(int)$
import org.elasticsearch.compute.data.IntBlock;

$elseif(long)$
import org.elasticsearch.compute.data.IntBlock;
import org.elasticsearch.compute.data.LongBlock;

$else$
import org.elasticsearch.compute.data.$Type$Block;
import org.elasticsearch.compute.data.IntBlock;

$endif$
import java.util.Arrays;

/**
 * Removes duplicate values from multivalued positions.
 * This class is generated. Edit {@code X-MultivalueDedupe.java.st} instead.
 */
public class MultivalueDedupe$Type$ {
    /**
     * The number of entries before we switch from and {@code n^2} strategy
     * with low overhead to an {@code n*log(n)} strategy with higher overhead.
     * The choice of number has been experimentally derived.
     */
$if(BytesRef)$
    private static final int ALWAYS_COPY_MISSING = 20;  // TODO BytesRef should try adding to the hash *first* and then comparing.
$elseif(double)$
    private static final int ALWAYS_COPY_MISSING = 110;
$else$
    private static final int ALWAYS_COPY_MISSING = 300;
$endif$

    private final $Type$Block block;
    private $type$[] work = new $type$[ArrayUtil.oversize(2, $BYTES$)];
    private int w;

    public MultivalueDedupe$Type$($Type$Block block) {
        this.block = block;
$if(BytesRef)$
        // TODO very large numbers might want a hash based implementation - and for BytesRef that might not be that big
        fillWork(0, work.length);
$endif$
    }

    /**
     * Remove duplicate values from each position and write the results to a
     * {@link Block} using an adaptive algorithm based on the size of the input list.
     */
    public $Type$Block dedupeToBlockAdaptive(BlockFactory blockFactory) {
        if (block.mvDeduplicated()) {
            block.incRef();
            return block;
        }
        try ($Type$Block.Builder builder = blockFactory.new$Type$BlockBuilder(block.getPositionCount())) {
            for (int p = 0; p < block.getPositionCount(); p++) {
                int count = block.getValueCount(p);
                int first = block.getFirstValueIndex(p);
                switch (count) {
                    case 0 -> builder.appendNull();
$if(BytesRef)$
                    case 1 -> builder.appendBytesRef(block.getBytesRef(first, work[0]));
$else$
                    case 1 -> builder.append$Type$(block.get$Type$(first));
$endif$
                    default -> {
                        /*
                         * It's better to copyMissing when there are few unique values
                         * and better to copy and sort when there are many unique values.
                         * The more duplicate values there are the more comparatively worse
                         * copyAndSort is. But we don't know how many unique values there
                         * because our job is to find them. So we use the count of values
                         * as a proxy that is fast to test. It's not always going to be
                         * optimal but it has the nice property of being quite quick on
                         * short lists and not n^2 levels of terrible on long ones.
                         *
                         * It'd also be possible to make a truly hybrid mechanism that
                         * switches from copyMissing to copyUnique once it collects enough
                         * unique values. The trouble is that the switch is expensive and
                         * makes kind of a "hole" in the performance of that mechanism where
                         * you may as well have just gone with either of the two other
                         * strategies. So we just don't try it for now.
                         */
                        if (count < ALWAYS_COPY_MISSING) {
                            copyMissing(first, count);
                            writeUniquedWork(builder);
                        } else {
                            copyAndSort(first, count);
                            deduplicatedSortedWork(builder);
                        }
                    }
                }
            }
            return builder.build();
        }
    }

    /**
     * Remove duplicate values from each position and write the results to a
     * {@link Block} using an algorithm with very low overhead but {@code n^2}
     * case complexity for larger. Prefer {@link #dedupeToBlockAdaptive}
     * which picks based on the number of elements at each position.
     */
    public $Type$Block dedupeToBlockUsingCopyAndSort(BlockFactory blockFactory) {
        if (block.mvDeduplicated()) {
            block.incRef();
            return block;
        }
        try ($Type$Block.Builder builder = blockFactory.new$Type$BlockBuilder(block.getPositionCount())) {
            for (int p = 0; p < block.getPositionCount(); p++) {
                int count = block.getValueCount(p);
                int first = block.getFirstValueIndex(p);
                switch (count) {
                    case 0 -> builder.appendNull();
$if(BytesRef)$
                    case 1 -> builder.appendBytesRef(block.getBytesRef(first, work[0]));
$else$
                    case 1 -> builder.append$Type$(block.get$Type$(first));
$endif$
                    default -> {
                        copyAndSort(first, count);
                        deduplicatedSortedWork(builder);
                    }
                }
            }
            return builder.build();
        }
    }

    /**
     * Remove duplicate values from each position and write the results to a
     * {@link Block} using an algorithm that sorts all values. It has a higher
     * overhead for small numbers of values at each position than
     * {@link #dedupeToBlockUsingCopyMissing} for large numbers of values the
     * performance is dominated by the {@code n*log n} sort. Prefer
     * {@link #dedupeToBlockAdaptive} unless you need the results sorted.
     */
    public $Type$Block dedupeToBlockUsingCopyMissing(BlockFactory blockFactory) {
        if (block.mvDeduplicated()) {
            block.incRef();
            return block;
        }
        try ($Type$Block.Builder builder = blockFactory.new$Type$BlockBuilder(block.getPositionCount())) {
            for (int p = 0; p < block.getPositionCount(); p++) {
                int count = block.getValueCount(p);
                int first = block.getFirstValueIndex(p);
                switch (count) {
                    case 0 -> builder.appendNull();
$if(BytesRef)$
                    case 1 -> builder.appendBytesRef(block.getBytesRef(first, work[0]));
$else$
                    case 1 -> builder.append$Type$(block.get$Type$(first));
$endif$
                    default -> {
                        copyMissing(first, count);
                        writeUniquedWork(builder);
                    }
                }
            }
            return builder.build();
        }
    }

    /**
     * Sort values from each position and write the results to a {@link Block}.
     */
    public $Type$Block sortToBlock(BlockFactory blockFactory, boolean ascending) {
        try ($Type$Block.Builder builder = blockFactory.new$Type$BlockBuilder(block.getPositionCount())) {
            for (int p = 0; p < block.getPositionCount(); p++) {
                int count = block.getValueCount(p);
                int first = block.getFirstValueIndex(p);
                switch (count) {
                    case 0 -> builder.appendNull();
$if(BytesRef)$
                    case 1 -> builder.appendBytesRef(block.getBytesRef(first, work[0]));
$else$
                    case 1 -> builder.append$Type$(block.get$Type$(first));
$endif$
                    default -> {
                        copyAndSort(first, count);
                        writeSortedWork(builder, ascending);
                    }
                }
            }
            return builder.build();
        }
    }

    /**
     * Dedupe values, add them to the hash, and build an {@link IntBlock} of
     * their hashes. This block is suitable for passing as the grouping block
     * to a {@link GroupingAggregatorFunction}.
     */
$if(BytesRef)$
    public MultivalueDedupe.HashResult hashAdd(BlockFactory blockFactory, BytesRefHash hash) {
$else$
    public MultivalueDedupe.HashResult hashAdd(BlockFactory blockFactory, LongHash hash) {
$endif$
        try (IntBlock.Builder builder = blockFactory.newIntBlockBuilder(block.getPositionCount())) {
            boolean sawNull = false;
            for (int p = 0; p < block.getPositionCount(); p++) {
                int count = block.getValueCount(p);
                int first = block.getFirstValueIndex(p);
                switch (count) {
                    case 0 -> {
                        sawNull = true;
                        builder.appendInt(0);
                    }
                    case 1 -> {
$if(BytesRef)$
                        BytesRef v = block.getBytesRef(first, work[0]);
$else$
                        $type$ v = block.get$Type$(first);
$endif$
                        hashAdd(builder, hash, v);
                    }
                    default -> {
                        if (count < ALWAYS_COPY_MISSING) {
                            copyMissing(first, count);
                            hashAddUniquedWork(hash, builder);
                        } else {
                            copyAndSort(first, count);
                            hashAddSortedWork(hash, builder);
                        }
                    }
                }
            }
            return new MultivalueDedupe.HashResult(builder.build(), sawNull);
        }
    }

    /**
     * Dedupe values and build an {@link IntBlock} of their hashes. This block is
     * suitable for passing as the grouping block to a {@link GroupingAggregatorFunction}.
     */
$if(BytesRef)$
    public IntBlock hashLookup(BlockFactory blockFactory, BytesRefHash hash) {
$else$
    public IntBlock hashLookup(BlockFactory blockFactory, LongHash hash) {
$endif$
        try (IntBlock.Builder builder = blockFactory.newIntBlockBuilder(block.getPositionCount())) {
            for (int p = 0; p < block.getPositionCount(); p++) {
                int count = block.getValueCount(p);
                int first = block.getFirstValueIndex(p);
                switch (count) {
                    case 0 -> builder.appendInt(0);
                    case 1 -> {
$if(BytesRef)$
                        BytesRef v = block.getBytesRef(first, work[0]);
$else$
                        $type$ v = block.get$Type$(first);
$endif$
                        hashLookupSingle(builder, hash, v);
                    }
                    default -> {
                        if (count < ALWAYS_COPY_MISSING) {
                            copyMissing(first, count);
                            hashLookupUniquedWork(hash, builder);
                        } else {
                            copyAndSort(first, count);
                            hashLookupSortedWork(hash, builder);
                        }
                    }
                }
            }
            return builder.build();
        }
    }

    /**
     * Build a {@link BatchEncoder} which deduplicates values at each position
     * and then encodes the results into a {@link byte[]} which can be used for
     * things like hashing many fields together.
     */
    public BatchEncoder batchEncoder(int batchSize) {
        return new BatchEncoder.$Type$s(batchSize) {
            @Override
            protected void readNextBatch() {
                int position = firstPosition();
                if (w > 0) {
                    // The last block didn't fit so we have to *make* it fit
$if(BytesRef)$
                    ensureCapacity(workSize(), w);
$else$
                    ensureCapacity(w);
$endif$
                    startPosition();
                    encodeUniquedWork(this);
                    endPosition();
                    position++;
                }
                for (; position < block.getPositionCount(); position++) {
                    int count = block.getValueCount(position);
                    int first = block.getFirstValueIndex(position);
                    switch (count) {
                        case 0 -> encodeNull();
                        case 1 -> {
$if(BytesRef)$
                            BytesRef v = block.getBytesRef(first, work[0]);
                            if (hasCapacity(v.length, 1)) {
$else$
                            $type$ v = block.get$Type$(first);
                            if (hasCapacity(1)) {
$endif$
                                startPosition();
                                encode(v);
                                endPosition();
                            } else {
                                work[0] = v;
                                w = 1;
                                return;
                            }
                        }
                        default -> {
                            if (count < ALWAYS_COPY_MISSING) {
                                copyMissing(first, count);
                            } else {
                                copyAndSort(first, count);
                                convertSortedWorkToUnique();
                            }
$if(BytesRef)$
                            if (hasCapacity(workSize(), w)) {
$else$
                            if (hasCapacity(w)) {
$endif$
                                startPosition();
                                encodeUniquedWork(this);
                                endPosition();
                            } else {
                                return;
                            }
                        }
                    }
                }
            }

$if(BytesRef)$
            private int workSize() {
                int size = 0;
                for (int i = 0; i < w; i++) {
                    size += work[i].length;
                }
                return size;
            }
$endif$
        };
    }

    /**
     * Copy all value from the position into {@link #work} and then
     * sorts it {@code n * log(n)}.
     */
    private void copyAndSort(int first, int count) {
        grow(count);
        int end = first + count;

        w = 0;
        for (int i = first; i < end; i++) {
$if(BytesRef)$
            work[w] = block.getBytesRef(i, work[w]);
            w++;
$else$
            work[w++] = block.get$Type$(i);
$endif$
        }

        Arrays.sort(work, 0, w);
    }

    /**
     * Fill {@link #work} with the unique values in the position by scanning
     * all fields already copied {@code n^2}.
     */
    private void copyMissing(int first, int count) {
        grow(count);
        int end = first + count;

$if(BytesRef)$
        work[0] = block.getBytesRef(first, work[0]);
$else$
        work[0] = block.get$Type$(first);
$endif$
        w = 1;
        i: for (int i = first + 1; i < end; i++) {
$if(BytesRef)$
            $type$ v = block.getBytesRef(i, work[w]);
$else$
            $type$ v = block.get$Type$(i);
$endif$
            for (int j = 0; j < w; j++) {
$if(BytesRef)$
                if (v.equals(work[j])) {
$else$
                if (v == work[j]) {
$endif$
                    continue i;
                }
            }
            work[w++] = v;
        }
    }

    /**
     * Writes an already deduplicated {@link #work} to a {@link $Type$Block.Builder}.
     */
    private void writeUniquedWork($Type$Block.Builder builder) {
        if (w == 1) {
            builder.append$Type$(work[0]);
            return;
        }
        builder.beginPositionEntry();
        for (int i = 0; i < w; i++) {
            builder.append$Type$(work[i]);
        }
        builder.endPositionEntry();
    }

    /**
     * Writes a sorted {@link #work} to a {@link $Type$Block.Builder}, skipping duplicates.
     */
    private void deduplicatedSortedWork($Type$Block.Builder builder) {
        builder.beginPositionEntry();
        $type$ prev = work[0];
        builder.append$Type$(prev);
        for (int i = 1; i < w; i++) {
$if(BytesRef)$
            if (false == prev.equals(work[i])) {
$else$
            if (prev != work[i]) {
$endif$
                prev = work[i];
                builder.append$Type$(prev);
            }
        }
        builder.endPositionEntry();
    }

    /**
     * Writes a {@link #work} to a {@link $Type$Block.Builder}.
     */
    private void writeSortedWork($Type$Block.Builder builder, boolean ascending) {
        builder.beginPositionEntry();
        for (int i = 0; i < w; i++) {
            if (ascending) {
                builder.append$Type$(work[i]);
            } else {
                builder.append$Type$(work[w - i - 1]);
            }
        }
        builder.endPositionEntry();
    }

    /**
     * Writes an already deduplicated {@link #work} to a hash.
     */
$if(BytesRef)$
    private void hashAddUniquedWork(BytesRefHash hash, IntBlock.Builder builder) {
$else$
    private void hashAddUniquedWork(LongHash hash, IntBlock.Builder builder) {
$endif$
        if (w == 1) {
            hashAdd(builder, hash, work[0]);
            return;
        }
        builder.beginPositionEntry();
        for (int i = 0; i < w; i++) {
            hashAdd(builder, hash, work[i]);
        }
        builder.endPositionEntry();
    }

    /**
     * Writes a sorted {@link #work} to a hash, skipping duplicates.
     */
$if(BytesRef)$
    private void hashAddSortedWork(BytesRefHash hash, IntBlock.Builder builder) {
$else$
    private void hashAddSortedWork(LongHash hash, IntBlock.Builder builder) {
$endif$
        if (w == 1) {
            hashAdd(builder, hash, work[0]);
            return;
        }
        builder.beginPositionEntry();
        $type$ prev = work[0];
        hashAdd(builder, hash, prev);
        for (int i = 1; i < w; i++) {
            if (false == valuesEqual(prev, work[i])) {
                prev = work[i];
                hashAdd(builder, hash, prev);
            }
        }
        builder.endPositionEntry();
    }

    /**
     * Looks up an already deduplicated {@link #work} to a hash.
     */
$if(BytesRef)$
    private void hashLookupUniquedWork(BytesRefHash hash, IntBlock.Builder builder) {
$else$
    private void hashLookupUniquedWork(LongHash hash, IntBlock.Builder builder) {
$endif$
        if (w == 1) {
            hashLookupSingle(builder, hash, work[0]);
            return;
        }

        int i = 1;
        long firstLookup = hashLookup(hash, work[0]);
        while (firstLookup < 0) {
            if (i >= w) {
                // Didn't find any values
                builder.appendNull();
                return;
            }
            firstLookup = hashLookup(hash, work[i]);
            i++;
        }

        /*
         * Step 2 - find the next unique value in the hash
         */
        boolean foundSecond = false;
        while (i < w) {
            long nextLookup = hashLookup(hash, work[i]);
            if (nextLookup >= 0) {
                builder.beginPositionEntry();
                appendFound(builder, firstLookup);
                appendFound(builder, nextLookup);
                i++;
                foundSecond = true;
                break;
            }
            i++;
        }

        /*
         * Step 3a - we didn't find a second value, just emit the first one
         */
        if (false == foundSecond) {
            appendFound(builder, firstLookup);
            return;
        }

        /*
         * Step 3b - we found a second value, search for more
         */
        while (i < w) {
            long nextLookup = hashLookup(hash, work[i]);
            if (nextLookup >= 0) {
                appendFound(builder, nextLookup);
            }
            i++;
        }
        builder.endPositionEntry();
    }

    /**
     * Looks up a sorted {@link #work} to a hash, skipping duplicates.
     */
$if(BytesRef)$
    private void hashLookupSortedWork(BytesRefHash hash, IntBlock.Builder builder) {
$else$
    private void hashLookupSortedWork(LongHash hash, IntBlock.Builder builder) {
$endif$
        if (w == 1) {
            hashLookupSingle(builder, hash, work[0]);
            return;
        }

        /*
         * Step 1 - find the first unique value in the hash
         *   i will contain the next value to probe
         *   prev will contain the first value in the array contained in the hash
         *   firstLookup will contain the first value in the hash
         */
        int i = 1;
        $type$ prev = work[0];
        long firstLookup = hashLookup(hash, prev);
        while (firstLookup < 0) {
            if (i >= w) {
                // Didn't find any values
                builder.appendNull();
                return;
            }
            prev = work[i];
            firstLookup = hashLookup(hash, prev);
            i++;
        }

        /*
         * Step 2 - find the next unique value in the hash
         */
        boolean foundSecond = false;
        while (i < w) {
            if (false == valuesEqual(prev, work[i])) {
                long nextLookup = hashLookup(hash, work[i]);
                if (nextLookup >= 0) {
                    prev = work[i];
                    builder.beginPositionEntry();
                    appendFound(builder, firstLookup);
                    appendFound(builder, nextLookup);
                    i++;
                    foundSecond = true;
                    break;
                }
            }
            i++;
        }

        /*
         * Step 3a - we didn't find a second value, just emit the first one
         */
        if (false == foundSecond) {
            appendFound(builder, firstLookup);
            return;
        }

        /*
         * Step 3b - we found a second value, search for more
         */
        while (i < w) {
            if (false == valuesEqual(prev, work[i])) {
                long nextLookup = hashLookup(hash, work[i]);
                if (nextLookup >= 0) {
                    prev = work[i];
                    appendFound(builder, nextLookup);
                }
            }
            i++;
        }
        builder.endPositionEntry();
    }

    /**
     * Writes a deduplicated {@link #work} to a {@link BatchEncoder.$Type$s}.
     */
    private void encodeUniquedWork(BatchEncoder.$Type$s encoder) {
        for (int i = 0; i < w; i++) {
            encoder.encode(work[i]);
        }
    }

    /**
     * Converts {@link #work} from sorted array to a deduplicated array.
     */
    private void convertSortedWorkToUnique() {
        $type$ prev = work[0];
        int end = w;
        w = 1;
        for (int i = 1; i < end; i++) {
            if (false == valuesEqual(prev, work[i])) {
$if(BytesRef)$
                prev = work[i];
                work[w].bytes = prev.bytes;
                work[w].offset = prev.offset;
                work[w].length = prev.length;
                w++;
            }
$else$
                prev = work[i];
                work[w++] = prev;
            }
$endif$
        }
    }

    private void grow(int size) {
$if(BytesRef)$
        int prev = work.length;
        work = ArrayUtil.grow(work, size);
        fillWork(prev, work.length);
$else$
        work = ArrayUtil.grow(work, size);
$endif$
    }

$if(BytesRef)$
    private void fillWork(int from, int to) {
        for (int i = from; i < to; i++) {
            work[i] = new BytesRef();
        }
    }
$endif$

$if(BytesRef)$
    private void hashAdd(IntBlock.Builder builder, BytesRefHash hash, BytesRef v) {
$else$
    private void hashAdd(IntBlock.Builder builder, LongHash hash, $type$ v) {
$endif$
$if(double)$
        appendFound(builder, hash.add(Double.doubleToLongBits(v)));
$else$
        appendFound(builder, hash.add(v));
$endif$
    }

$if(BytesRef)$
    private long hashLookup(BytesRefHash hash, BytesRef v) {
$else$
    private long hashLookup(LongHash hash, $type$ v) {
$endif$
$if(double)$
        return hash.find(Double.doubleToLongBits(v));
$else$
        return hash.find(v);
$endif$
    }

$if(BytesRef)$
    private void hashLookupSingle(IntBlock.Builder builder, BytesRefHash hash, BytesRef v) {
$else$
    private void hashLookupSingle(IntBlock.Builder builder, LongHash hash, $type$ v) {
$endif$
        long found = hashLookup(hash, v);
        if (found >= 0) {
            appendFound(builder, found);
        } else {
            builder.appendNull();
        }
    }

    private void appendFound(IntBlock.Builder builder, long found) {
        builder.appendInt(Math.toIntExact(BlockHash.hashOrdToGroupNullReserved(found)));
    }

    private static boolean valuesEqual($type$ lhs, $type$ rhs) {
$if(BytesRef)$
        return lhs.equals(rhs);
$else$
        return lhs == rhs;
$endif$
    }
}
