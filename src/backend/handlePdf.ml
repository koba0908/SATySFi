
(* for test *)
let print_for_debug msgln = ()


open HorzBox


type t = Pdf.t * Pdfpage.t list * file_path


let left_margin = Length.of_pdf_point 75.   (* temporary; should be variable *)
let top_margin = Length.of_pdf_point 100.   (* temporary; should be variable *)
let leading = Length.of_pdf_point 32.       (* temporary; should be variable *)


let ops_test_box rgb (xpos, ypos) wid hgt =
  [
    Graphics.op_q;
    Graphics.op_RG rgb;
    Graphics.op_re (xpos, ypos) (wid, Length.negate hgt);
    Graphics.op_S;
    Graphics.op_Q;
  ]


let get_paper_height (paper : Pdfpaper.t) : length =
  let dpi = 300. in  (* temporary; should be variable *)
  let pdfpt = Pdfunits.convert dpi (Pdfpaper.unit paper) Pdfunits.PdfPoint (Pdfpaper.height paper) in
    Length.of_pdf_point pdfpt


let rec ops_of_evaled_horz_box yposbaseline hgt dpt (xpos, opacc) evhb =
    match evhb with
    | EvHorz(wid, EvHorzEmpty) -> (xpos +% wid, opacc)
    | EvHorz(wid, EvHorzFrame(hgt_frame, dpt_frame, deco, evhblst)) ->
        let ops_background =
          deco (xpos, yposbaseline) wid hgt_frame dpt_frame
        in
        let ops_foreground = [] in
        let opaccinit = List.rev_append ops_background opacc in
        let (xposnew, opaccsub) =
          evhblst @|> (xpos, opaccinit) @|> List.fold_left (ops_of_evaled_horz_box yposbaseline hgt dpt)
        in
        let opaccnew = List.rev_append ops_foreground opaccsub in
          (xposnew, opaccnew)

    | EvHorz(wid, EvHorzString(info, otxt)) ->
        let (tag, enc) = FontInfo.get_tag_and_encoding info.font_abbrev in
        let opword = Graphics.op_TJ (OutputText.to_TJ_argument otxt) in
        let opcolor = Graphics.pdfop_of_text_color info.text_color in
        let ops =
          [
(*
            (* begin: for test; encloses every word with a red box *)
            Graphics.op_q;
            Graphics.op_RG (1.0, 0.5, 0.5);
            Graphics.op_m (xpos, yposbaseline);
            Graphics.op_l (xpos +% wid, yposbaseline);
            Graphics.op_re (xpos, yposbaseline +% hgt) (wid, Length.zero -% (hgt -% dpt));
            Graphics.op_S;
            Graphics.op_Q;
            (* end: for test *)
*)
            Graphics.op_cm (Length.zero, Length.zero);
            Graphics.op_q;
            opcolor;
            Graphics.op_BT;
            Graphics.op_Tm_translate (xpos, yposbaseline);
            Graphics.op_Tf tag info.font_size;
            opword;
            Graphics.op_ET;
            Graphics.op_Q;
          ]
        in
        let opaccnew = List.rev_append ops opacc in
          (xpos +% wid, opaccnew)

    | EvHorz(wid, EvHorzEmbeddedVert(hgt, dpt, evvblst)) ->
        let ((_, _), opaccnew) = ops_of_evaled_vert_box_list (xpos, yposbaseline +% hgt) opacc evvblst in
          (xpos +% wid, opaccnew)


and ops_of_evaled_vert_box_list (xinit, yinit) opaccinit evvblst =
  evvblst @|> ((xinit, yinit), opaccinit) @|> List.fold_left (fun ((xpos, ypos), opacc) evvb ->
    match evvb with
    | EvVertFixedEmpty(vskip) ->
(*
        (* begin: for debug *)
        let opacc =
          List.rev_append
            (ops_test_box (0.5, 1.0, 0.5) (xpos +% (Length.of_pdf_point 50.), ypos) (Length.of_pdf_point 200.) vskip)
            opacc
        in
        (* end: for debug *)
*)
        ((xpos, ypos -% vskip), opacc)

    | EvVertLine(hgt, dpt, evhblst) ->
        let yposbaseline = ypos -% hgt in
        let (_, opaccend) =
          evhblst @|> (xpos, opacc) @|> List.fold_left (ops_of_evaled_horz_box yposbaseline hgt dpt)
        in
(*
        (* begin: for debug *)
        let opaccend =
          List.rev_append (List.append
            (ops_test_box (1.0, 0.5, 0.5) (xpos, ypos) (Length.of_pdf_point 100.) hgt)
            (ops_test_box (1.0, 0.5, 0.5) (xpos, ypos -% hgt) (Length.of_pdf_point 100.) (Length.negate dpt)))
            opaccend in
        (* end: for debug *)
*)
          ((xpos, yposbaseline +% dpt), opaccend)

    | EvVertFrame(pads, deco, wid, evvblstsub) ->
        let xpossubinit = xpos +% pads.paddingL in
        let ypossubinit = ypos -% pads.paddingT in
        let ((_, ypossub), opaccsub) = ops_of_evaled_vert_box_list (xpossubinit, ypossubinit) opacc evvblstsub in
        let yposend = ypossub -% pads.paddingB in
        let ops_background = deco (xpos, yposend) wid (ypos -% yposend) Length.zero in
          ((xpos, yposend), List.rev_append ops_background opaccsub)
  )


let write_page (paper : Pdfpaper.t) (evvblst : evaled_vert_box list) ((pdf, pageacc, flnm) : t) : t =

  let xinit = left_margin in
  let yinit = (get_paper_height paper) -% top_margin in
  let (_, opaccend) = ops_of_evaled_vert_box_list (xinit, yinit) [] evvblst in

  let oplst = List.rev opaccend in

  let pagenew =
    { (Pdfpage.blankpage paper) with
        Pdfpage.content = [Pdfops.stream_of_ops oplst];
    }
  in
    (pdf, pagenew :: pageacc, flnm)


let create_empty_pdf (flnm : file_path) : t =
  let pdf = Pdf.empty () in
    (pdf, [], flnm)


let write_to_file ((pdf, pageacc, flnm) : t) : unit =
  let fontdict = FontInfo.get_font_dictionary pdf in
  let irfontdict =
    Pdf.addobj pdf (Pdf.Dictionary[("/Font", fontdict)])
  in
  let pagelst =
    pageacc |> List.rev |> List.map (fun page ->
      { page with Pdfpage.resources = Pdf.Indirect(irfontdict); }
    )
  in
  let (pdfsub, irpageroot) = Pdfpage.add_pagetree pagelst pdf in
  let pdfout = Pdfpage.add_root irpageroot [] pdfsub in
    Pdfwrite.pdf_to_file pdfout flnm