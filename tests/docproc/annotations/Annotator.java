// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.docproc.DocumentProcessor;
import com.yahoo.docproc.Processing;
import com.yahoo.document.*;
import com.yahoo.document.annotation.*;
import com.yahoo.document.datatypes.StringFieldValue;
import com.yahoo.document.datatypes.IntegerFieldValue;
import com.yahoo.document.datatypes.Struct;
import java.util.logging.Logger;

/**
 * @author Einar M R Rosenvinge
 */
public class Annotator extends DocumentProcessor {

    private static Logger log = Logger.getLogger(Annotator.class.getName());

	@Override
	public Progress process(Processing processing) {
		for (DocumentOperation op : processing.getDocumentOperations()) {
			if (!(op instanceof DocumentPut)) {
				continue;
			}
			Document document = ((DocumentPut)op).getDocument();
			log.info("Getting DocumentTypeManager.");
			DocumentTypeManager manager = processing.getService().getDocumentTypeManager();
			log.info("Got DocumentTypeManager " + manager);
			AnnotationTypeRegistry registry = manager.getAnnotationTypeRegistry();
			log.info("Got AnnotationTypeRegistry " + registry);
			AnnotationType personType = registry.getType("person");
			AnnotationType artistType = registry.getType("artist");
			AnnotationType dateType = registry.getType("date");
			AnnotationType placeType = registry.getType("place");
			AnnotationType eventType = registry.getType("event");

			SpanList root = new SpanList();
			SpanTree tree = new SpanTree("meaningoflife", root);

			SpanNode personSpan = new Span(0,5);
			SpanNode artistSpan = new Span(5,10);
			SpanNode dateSpan = new Span(10,15);
			SpanNode placeSpan = new Span(15,20);

			root.add(personSpan);
			root.add(artistSpan);
			root.add(dateSpan);
			root.add(placeSpan);

			Struct personValue = new Struct(manager.getDataType("annotation.person"));
			personValue.setFieldValue("name", "george washington");
			Annotation person = new Annotation(personType, personValue);
			tree.annotate(personSpan, person);

			Struct artistValue = new Struct(manager.getDataType("annotation.artist"));
			artistValue.setFieldValue("name", "elvis presley");
			artistValue.setFieldValue("instrument", new IntegerFieldValue(20));
			Annotation artist = new Annotation(artistType, artistValue);
			tree.annotate(artistSpan, artist);

			Struct dateValue = new Struct(manager.getDataType("annotation.date"));
			dateValue.setFieldValue("exacttime", 123456789L);
			Annotation date = new Annotation(dateType, dateValue);
			tree.annotate(dateSpan, date);

			Struct placeValue = new Struct(manager.getDataType("annotation.place"));
			placeValue.setFieldValue("lat", 1467L);
			placeValue.setFieldValue("lon", 789L);
			Annotation place = new Annotation(placeType, placeValue);
			tree.annotate(placeSpan, place);

			Struct eventValue = new Struct(manager.getDataType("annotation.event"));
			eventValue.setFieldValue("description", "Big concert");
			eventValue.setFieldValue("person", new AnnotationReference((AnnotationReferenceDataType) manager.getDataType("annotationreference<person>"), person));
			eventValue.setFieldValue("date", new AnnotationReference((AnnotationReferenceDataType) manager.getDataType("annotationreference<date>"), date));
			eventValue.setFieldValue("place", new AnnotationReference((AnnotationReferenceDataType) manager.getDataType("annotationreference<place>"), place));
			Annotation event = new Annotation(eventType, eventValue);
			tree.annotate(root, event);

			StringFieldValue content = new StringFieldValue("This is the story of a big concert by Elvis and a special guest appearance by George Washington");
			content.setSpanTree(tree);

			document.setFieldValue(document.getDataType().getField("content"), content);
			log.info("Processed " + document);
		}
		log.info("Returning Progress.DONE");
		return Progress.DONE;
	}
}
