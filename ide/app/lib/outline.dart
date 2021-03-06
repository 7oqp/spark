// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.outline;

import 'dart:async';
import 'dart:html' as html;

import '../lib/services.dart' as services;

/**
 * Defines a class to build an outline UI for a given block of code.
 */
class Outline {
  html.DivElement _outlineDiv;
  html.UListElement _rootList;
  html.DivElement _outlineScrollableDiv;
  html.DivElement _outlineContentDiv;

  services.AnalyzerService analyzer;

  List<OutlineTopLevelItem> children = [];
  StreamController childSelectedController = new StreamController();
  Stream get onChildSelected => childSelectedController.stream;

  Outline(services.Services services, this._outlineDiv) {
    analyzer = services.getService("analyzer");

    // TODO(ericarnold): This should be done in polymer.
    _outlineDiv.id = "outline";

    _outlineContentDiv = new html.DivElement()
        ..id = "outlineContent";

    _outlineScrollableDiv = new html.DivElement()
        ..id = "outlineScrollable"
        ..onMouseWheel.listen((html.MouseEvent event) {
          event.stopPropagation();
        });

    _outlineContentDiv.append(_outlineScrollableDiv);
    _outlineDiv.append(_outlineContentDiv);

    html.SpanElement showGlyph = new html.SpanElement()
        ..classes.add('glyphicon')
        ..classes.add('glyphicon-list')
        ..id = "showOutlineGlyph";
    html.SpanElement hideGlyph = new html.SpanElement()
        ..classes.add('glyphicon')
        ..classes.add('glyphicon-play')
        ..id = "hideOutlineGlyph";

    html.ButtonElement toggleButton = new html.ButtonElement();
    toggleButton = new html.ButtonElement()
        ..id = "toggleOutlineButton"
        ..append(hideGlyph)
        ..append(showGlyph)
        ..onClick.listen((e) {
          _toggle();
        });

    _outlineDiv.append(toggleButton);
  }

  bool get visible => !_outlineDiv.classes.contains('collapsed');
  set visible(bool value) {
    if (value != visible) {
      _outlineDiv.classes.toggle('collapsed');
    }
  }

  /**
   * Builds or rebuilds the outline UI based on the given String of code.
   */
  Future build(String code) {
    return analyzer.getOutlineFor(code).then((services.Outline model) {
      _populate(model);
    });
  }

  void _populate(services.Outline outline) {
    // TODO(ericarnold): Is there anything else that needs to be done to
    //    ensure there are no memory leaks?
    children = [];
    if (_rootList != null) {
      _rootList.remove();
    }

    _rootList = new html.UListElement();
    _outlineScrollableDiv.append(_rootList);

    for (services.OutlineTopLevelEntry data in outline.entries) {
      _create(data);
    }
  }

  OutlineTopLevelItem _create(services.OutlineTopLevelEntry data) {
    if (data is services.OutlineClass) {
      return _addClass(data);
    } else if (data is services.OutlineTopLevelVariable) {
      return _addVariable(data);
    } else if (data is services.OutlineTopLevelFunction) {
      return _addFunction(data);
    } else {
      throw new UnimplementedError("Unknown type");
    }
  }

  /**
   * Toggles visibility of the outline.  Returns true if showing.
   */
  void _toggle() {
    _outlineDiv.classes.toggle('collapsed');
  }

  OutlineTopLevelItem _addItem(OutlineTopLevelItem item) {
    _rootList.append(item.element);
    item.onClick.listen((event) => childSelectedController.add(item));
    children.add(item);
    return item;
  }

  OutlineTopLevelVariable _addVariable(services.OutlineTopLevelVariable data) =>
      _addItem(new OutlineTopLevelVariable(data));

  OutlineTopLevelFunction _addFunction(services.OutlineTopLevelFunction data) =>
      _addItem(new OutlineTopLevelFunction(data));

  OutlineClass _addClass(services.OutlineClass data) {
    OutlineClass classItem = new OutlineClass(data);
    classItem.onChildSelected.listen((event) =>
        childSelectedController.add(event));
    _addItem(classItem);
    return classItem;
  }
}

abstract class OutlineItem {
  html.LIElement _element;
  services.OutlineEntry _data;
  html.AnchorElement _anchor;

  OutlineItem(this._data, String cssClassName) {
    _element = new html.LIElement();
    _anchor = new html.AnchorElement(href: "#");
    _anchor.text = _data.name;

    _element.append(_anchor);
    _element.classes.add("outlineItem $cssClassName");
  }

  Stream get onClick => _anchor.onClick;
  int get startOffset => _data.startOffset;
  int get endOffset => _data.endOffset;
  html.LIElement get element => _element;
}

abstract class OutlineTopLevelItem extends OutlineItem {
  OutlineTopLevelItem(services.OutlineTopLevelEntry data, String cssClassName)
      : super(data, "topLevel $cssClassName");
}

class OutlineTopLevelVariable extends OutlineTopLevelItem {
  OutlineTopLevelVariable(services.OutlineTopLevelVariable data)
      : super(data, "variable");
}

class OutlineTopLevelFunction extends OutlineTopLevelItem {
  OutlineTopLevelFunction(services.OutlineTopLevelFunction data)
      : super(data, "function");
}

class OutlineClass extends OutlineTopLevelItem {
  html.UListElement _childrenRootElement = new html.UListElement();

  List<OutlineClassMember> members = [];
  StreamController childSelectedController = new StreamController();
  Stream get onChildSelected => childSelectedController.stream;

  OutlineClass(services.OutlineClass data)
      : super(data, "class") {
    _element.append(_childrenRootElement);
    _populate(data);
  }

  OutlineClassMember _addItem(OutlineClassMember item) {
    _childrenRootElement.append(item.element);
    item.onClick.listen((event) => childSelectedController.add(item));
    members.add(item);
    return item;
  }

  void _populate(services.OutlineClass classData) {
    for (services.OutlineEntry data in classData.members) {
      _create(data);
    }
  }

  OutlineItem _create(services.OutlineEntry data) {
    if (data is services.OutlineMethod) {
      return addMethod(data);
    } else if (data is services.OutlineProperty) {
      return addProperty(data);
    } else {
      throw new UnimplementedError("Unknown type");
    }
  }

  OutlineMethod addMethod(services.OutlineMethod data) =>
      _addItem(new OutlineMethod(data));
  OutlineProperty addProperty(services.OutlineProperty data) =>
      _addItem(new OutlineProperty(data));
}

abstract class OutlineClassMember extends OutlineItem {
  OutlineClassMember(services.OutlineMember data, String cssClassName)
      : super(data, cssClassName);
}

class OutlineMethod extends OutlineClassMember {
  OutlineMethod(services.OutlineMethod data)
      : super(data, "method");
}

class OutlineProperty extends OutlineClassMember {
  OutlineProperty(services.OutlineProperty data)
      : super(data, "property");
}
